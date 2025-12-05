function __bzip2_url(version)
    return format("https://sourceware.org/pub/bzip2/bzip2-%s.tar.gz", version)
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make" },
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

local function bzip2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = {}
    for _, file in ipairs(os.files(path.join(libdir, "libbz2*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    if #out == 0 then
        table.insert(out, "libbz2.so")
        table.insert(out, "libbz2.so.1")
        table.insert(out, "libbz2.so.1.0")
    end
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_dir = path.absolute("bzip2-" .. pkginfo.version())
    local prefix = pkginfo.install_dir()
    
    log.info("1.Building bzip2...")
    os.cd(scode_dir)
    
    local make_cmd = "make -j24 install"
        .. " DESTDIR=" .. prefix
        .. " PREFIX=" .. prefix
        .. " CFLAGS=\"-fPIC -O2\""
    
    system.exec(make_cmd)
    
    -- Also build shared library
    log.info("2.Building shared library...")
    system.exec("make -j24 -f Makefile-libbz2_so")
    os.cp("libbz2.so*", path.join(prefix, "lib"))
    
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
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)
    
    -- Copy bzlib.h header
    local bzlib_h = path.join(hdr_dir, "bzlib.h")
    if os.isfile(bzlib_h) then
        os.cp(bzlib_h, sys_usr_includedir, { force = true })
    end
    
    -- Copy libraries to sysroot
    local sys_usr_libdir = path.join(system.subos_sysrootdir(), "usr/lib")
    os.mkdir(sys_usr_libdir)
    for _, lib in ipairs(os.files(path.join(libdir, "libbz2*.so*"))) do
        os.cp(lib, sys_usr_libdir, { force = true })
    end
    
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
    
    os.tryrm(path.join(sys_usr_includedir, "bzlib.h"))
    
    local sys_usr_libdir = path.join(system.subos_sysrootdir(), "usr/lib")
    for _, lib in ipairs(os.files(path.join(sys_usr_libdir, "libbz2*.so*"))) do
        os.tryrm(lib)
    end
    
    return true
end
