package = {
    homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html",

    name = "libreadline",
    description = "GNU Readline Library for Command-line Editing",

    authors = "Chet Ramey",
    licenses = "GPL",
    repo = "https://ftp.gnu.org/gnu/readline/",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"cli", "terminal"},
    keywords = {"readline", "lib", "cli", "shell"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make@4.3", "configure-project-installer" },
            ["latest"] = { ref = "8.2" },
            ["8.2"] = {},
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local libs = {
    "libreadline.so",
    "libreadline.so.8",
    "libreadline.a",
    "libhistory.so",
    "libhistory.so.8",
    "libhistory.a",
}

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include/readline")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg)
    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "libreadline-binding-tree@" .. pkginfo.version()
    xvm.add("libreadline-binding-tree")

    log.warn("add libs...")
    local config = {
        type = "lib",
        version = "readline-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add header files to sysroot...")

    local hdr_dir = path.join(pkginfo.install_dir(), "include", "readline")
    os.cp(hdr_dir, sys_usr_includedir)

    xvm.add("libreadline", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("libreadline")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "readline-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "readline"))

    xvm.remove("libreadline-binding-tree")

    return true
end