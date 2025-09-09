package = {
    homepage = "https://zlib.net",

    -- base info
    name = "zlib",
    description = "A Massively Spiffy Yet Delicately Unobtrusive Compression Library",

    authors = "Jean-loup Gailly, Mark Adler",
    licenses = "https://zlib.net/zlib_license.html",
    repo = "https://github.com/torvalds/linux",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"compression"},
    keywords = {"lib", "devel", "compression", "zlib"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make@4.3" },
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = { },
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local libs = {
    "libz.so",
    "libz.so.1",
    "libz.a",
}

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    system.exec("configure-project-installer " .. pkginfo.install_dir()
    .. " --xpkg-scode " .. xpkg)
    return os.isdir(pkginfo.install_dir())
end

function config()

    local binding_root = "zlib@" .. pkginfo.version()
    local zlib_version = "zlib-" .. pkginfo.version()

    xvm.add("zlib")

    local config = {
        type = "lib",
        version = zlib_version,
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = binding_root,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add zlib.h to sysroot/usr/include ...")

    os.cd(path.join(pkginfo.install_dir(), "include"))
    os.cp("zlib.h", sys_usr_includedir)
    os.cp("zconf.h", sys_usr_includedir)

    return true
end

function uninstall()
    xvm.remove("zlib")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "zlib-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "zlib.h"))
    os.tryrm(path.join(sys_usr_includedir, "zconf.h"))

    return true
end