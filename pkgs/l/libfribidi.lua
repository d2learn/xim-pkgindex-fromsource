function __libfribidi_url(version)
    return format("https://github.com/fribidi/fribidi/releases/download/v%s/fribidi-%s.tar.xz", version, version)
end

package = {
    spec = "1",

    homepage = "https://fribidi.org/",

    -- base info
    name = "libfribidi",
    description = "Free implementation of the Unicode Bidirectional Algorithm",

    authors = "Fribidi Team",
    licenses = "LGPL-2.1",
    repo = "https://github.com/fribidi/fribidi",
    docs = "https://fribidi.org/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "library", "text", "unicode" },
    keywords = { "fribidi", "bidi", "unicode", "text", "arabic", "hebrew" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "fribidi",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
            },
            ["latest"] = { ref = "1.0.13" },
            ["1.0.13"] = {
                url = {
                    GLOBAL = __libfribidi_url("1.0.13"),
                    CN = __libfribidi_url("1.0.13"),
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
local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

local function libfribidi_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libfribidi*.so*"))
    if #out == 0 then
        out = { "libfribidi.so", "libfribidi.so.0" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "fribidi-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libfribidi")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libfribidi (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "-Ddocs=false -Dtests=false && ninja -j8 && ninja install'",
        sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libfribidi libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libfribidi-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libfribidi_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding programs...")
    local bindir = path.join(pkginfo.install_dir(), "bin")
    if os.isdir(bindir) then
        for _, prog in ipairs(package.programs) do
            local prog_path = path.join(bindir, prog)
            if os.isfile(prog_path) then
                xvm.add(prog, {
                    type = "bin",
                    version = "libfribidi-" .. pkginfo.version(),
                    bindir = bindir,
                    alias = prog,
                    filename = prog,
                })
            end
        end
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local fb_dir = path.join(pkginfo.install_dir(), "include", "fribidi")
    if os.isdir(fb_dir) then
        os.cp(fb_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/fribidi*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
        end
    end

    xvm.add("libfribidi")
    return true
end

function uninstall()
    xvm.remove("libfribidi")
    for _, lib in ipairs(libfribidi_libs()) do
        xvm.remove(lib, "libfribidi-" .. pkginfo.version())
    end
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "libfribidi-" .. pkginfo.version())
    end
    os.tryrm(path.join(_sys_usr_includedir(), "fribidi"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/fribidi*.pc'", _sys_usr_libdir()
    ))
    return true
end
