function __bzip2_url(version)
    return format("https://sourceware.org/pub/bzip2/bzip2-%s.tar.gz", version)
end

package = {
    spec = "1",

    homepage = "https://sourceware.org/bzip2/",

    -- base info
    name = "bzip2",
    description = "Compression library and utility",

    authors = "Julian Seward",
    licenses = "BSD",
    repo = "https://gitlab.com/bzip2/bzip2",
    docs = "https://sourceware.org/bzip2/docs.html",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "compression", "library", "utility" },
    keywords = { "bzip2", "compression", "bz2", "bzlib" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "bzip2",
        "bunzip2",
        "bzcat",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "1.0.8" },
            ["1.0.8"] = {
                url = {
                    GLOBAL = __bzip2_url("1.0.8"),
                    CN = __bzip2_url("1.0.8"),
                },
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- The xpkg sandbox blocks `os.files`/`os.match` glob helpers, so list files
-- via a shell pipe. Returns just the filenames (basename), not full paths.
local function _ls_glob(globpat)
    local out = {}
    local h = io.popen("ls -1 " .. globpat .. " 2>/dev/null")
    if not h then return out end
    for line in h:lines() do
        if line ~= "" then table.insert(out, path.filename(line)) end
    end
    h:close()
    return out
end

local function bzip2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libbz2*.so*"))
    if #out == 0 then
        out = { "libbz2.so", "libbz2.so.1", "libbz2.so.1.0" }
    end
    return out
end

-- Resolve sysroot paths inside hooks so they pick up the active subos
-- (top-level evaluation may run before xlings sets the sysroot).
local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    -- Sandbox blocks `path.absolute`/`os.curdir`, so derive the source dir
    -- from `pkginfo.install_file()` (absolute tarball path in runtimedir).
    -- `os.cd` doesn't propagate into `system.exec` children — pass `-C` to
    -- make.
    local scode_dir = path.join(
        path.directory(pkginfo.install_file()),
        "bzip2-" .. pkginfo.version()
    )
    local prefix = pkginfo.install_dir()

    log.info("1.Building bzip2 (static lib + binaries)...")
    system.exec(string.format(
        "make -C %s -j8 install DESTDIR=%s PREFIX=%s",
        scode_dir, prefix, prefix
    ))

    -- Make-libbz2_so reuses .o files from the previous build; the static
    -- build produced non-PIC objects, so the shared link fails with
    -- R_X86_64_32 against .rodata. `make clean` forces fresh -fPIC objects.
    log.info("2.Building shared library...")
    system.exec(string.format("make -C %s clean", scode_dir))
    system.exec(string.format(
        "make -C %s -j8 -f Makefile-libbz2_so", scode_dir
    ))
    -- Sandbox `os.cp` ignores glob patterns silently — use shell cp.
    -- Also create the linker-name (libbz2.so) and SONAME (libbz2.so.1)
    -- symlinks; the bzip2 Makefile-libbz2_so only creates the .1.0 → .1.0.x
    -- pair, but the standard search order needs the unversioned symlink for
    -- `-lbz2` to resolve.
    system.exec(string.format(
        "sh -c 'cp -P %s/libbz2.so* %s/lib/ && cd %s/lib && ln -sf libbz2.so.1.0 libbz2.so.1 && ln -sf libbz2.so.1 libbz2.so'",
        scode_dir, prefix, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding bzip2 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding_tree_root = string.format("bzip2@%s", pkginfo.version())

    xvm.add("bzip2", { bindir = bindir })

    local config = {
        type = "lib",
        version = "bzip2-" .. pkginfo.version(),
        bindir = libdir,
        binding = binding_tree_root,
    }

    for _, lib in ipairs(bzip2_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding programs...")
    if os.isdir(bindir) then
        for _, prog in ipairs(package.programs) do
            local prog_path = path.join(bindir, prog)
            if os.isfile(prog_path) then
                xvm.add(prog, {
                    type = "bin",
                    version = "bzip2-" .. pkginfo.version(),
                    bindir = bindir,
                    binding = binding_tree_root,
                })
            end
        end
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local bzlib_h = path.join(pkginfo.install_dir(), "include", "bzlib.h")
    if os.isfile(bzlib_h) then
        system.exec(string.format("cp -f %s %s/", bzlib_h, sys_inc))
    end

    local sys_lib = _sys_usr_libdir()
    os.mkdir(sys_lib)
    -- Sandbox `os.cp` ignores globs — use shell cp. `|| true` so the build
    -- doesn't fail if no .so files exist (static-only install).
    system.exec(string.format(
        "sh -c 'cp -Pf %s/libbz2*.so* %s/ 2>/dev/null || true'",
        libdir, sys_lib
    ))

    return true
end

function uninstall()
    xvm.remove("bzip2")

    for _, lib in ipairs(bzip2_libs()) do
        xvm.remove(lib, "bzip2-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "bzip2-" .. pkginfo.version())
    end

    os.tryrm(path.join(_sys_usr_includedir(), "bzlib.h"))

    local sys_lib = _sys_usr_libdir()
    for _, lib in ipairs(_ls_glob(path.join(sys_lib, "libbz2*.so*"))) do
        os.tryrm(path.join(sys_lib, lib))
    end

    return true
end
