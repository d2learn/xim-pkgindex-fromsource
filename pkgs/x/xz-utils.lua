package = {
    homepage = "https://tukaani.org/xz/",

    name = "xz-utils",
    description = "XZ Utils: lossless compression software with liblzma library",

    authors = "Lasse Collin",
    licenses = "https://tukaani.org/xz/xz-file-format.txt",
    repo = "https://git.tukaani.org/xz.git/",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compression"},
    keywords = {"xz", "lzma", "lib", "compression"},
    programs = { "xz", "unxz", "lzma", "unlzma", "xzcat", "lzcat", "liblzma" },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make@4.3", "configure-project-installer" },
            ["latest"] = { ref = "5.4.5" },
            ["5.4.5"] = {},
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local libs = {
    "liblzma.so",
    "liblzma.so.5",
    "liblzma.a",
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
    local version_tag = "xz-utils-binding-tree@" .. pkginfo.version()
    xvm.add("xz-utils-binding-tree")

    log.warn("add programs files...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = path.join(pkginfo.install_dir(), "bin"),
            binding = version_tag,
        })
    end

    log.warn("add libs...")

    local config = {
        type = "lib",
        version = "xz-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add header files to sysroot...")
    local includedir = path.join(pkginfo.install_dir(), "include", "lzma")
    
    os.tryrm(path.join(sys_usr_includedir, "lzma"))
    os.cp(includedir, path.join(sys_usr_includedir, "lzma"), { force = true})

    os.cd(path.join(pkginfo.install_dir(), "include"))
    os.cp("lzma.h", sys_usr_includedir)

    xvm.add("xz-utils", { binding = version_tag})

    return true
end

function uninstall()

    xvm.remove("xz-utils")

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    for _, lib in ipairs(libs) do
        xvm.remove(lib, "xz-" .. pkginfo.version())
    end
    os.tryrm(path.join(sys_usr_includedir, "lzma.h"))
    os.tryrm(path.join(sys_usr_includedir, "lzma"))

    xvm.remove("xz-utils-binding-tree")

    return true
end