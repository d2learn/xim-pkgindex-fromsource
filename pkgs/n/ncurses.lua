package = {
    homepage = "https://invisible-island.net/ncurses/",
    name = "ncurses",
    description = "The New Curses library: terminal UI support for character-cell displays",
    authors = "Thomas E. Dickey",
    licenses = "MIT",
    repo = "https://github.com/mirror/ncurses",
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "terminal", "library", "ui" },
    keywords = { "ncurses", "tput", "termcap", "terminfo", "libtinfo", "text-ui" },

    programs = {
        "clear", "infocmp", "ncursesw6-config",
        "tabs", "tput", "tic", "toe", "tset",
        "captoinfo", "infotocap", "reset",  -- link file
    },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "configure-project-installer" },
            ["latest"] = { ref = "6.4" },
            ["6.4"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local libs = {
    "libform.so", "libform.so.6", "libform.a",
    "libmenu.so", "libmenu.so.6", "libmenu.a",
    "libncurses.so", "libncurses.so.6", "libncurses.a",
    "libpanel.so", "libpanel.so.6", "libpanel.a",
    "libtinfo.so", "libtinfo.so.6", "libtinfo.a",
}

local xpkg_binding_tree = package.name .. "-binding-tree"
local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg
        .. " --args " .. [[ "--with-shared --with-termlib" ]] -- for libinfo
    )
    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local includedir = path.join(pkginfo.install_dir(), "include")

    log.info("Registering CLI programs...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = bindir,
            binding = binding_tree_version_tag,
        })
    end

    log.info("Registering libraries...")
    local config = {
        type = "lib",
        version = package.name .. "-" .. pkginfo.version(),
        bindir = libdir,
        binding = binding_tree_version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Installing headers to sysroot...")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            local name = path.filename(subdir)
            os.tryrm(path.join(sys_usr_includedir, name))
            os.cp(subdir, path.join(sys_usr_includedir, name), { force = true })
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.cp(file, sys_usr_includedir)
        end
    end

    xvm.add(package.name, { binding = binding_tree_version_tag })
    return true
end

function uninstall()

    xvm.remove(package.name)

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end

    for _, lib in ipairs(libs) do
        xvm.remove(lib, package.name .. "-" .. pkginfo.version())
    end

    local includedir = path.join(pkginfo.install_dir(), "include")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(subdir)))
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(file)))
        end
    end

    xvm.remove(xpkg_binding_tree)
    return true
end