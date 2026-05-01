function __ncurses_url(version)
    return format("https://invisible-mirror.net/archives/ncurses/ncurses-%s.tar.gz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "6.4" },
            ["6.4"] = {
                url = __ncurses_url("6.4"),
                sha256 = nil,
            },
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

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (os.cd doesn't propagate to system.exec children).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "ncurses-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-ncurses")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing ncurses (autotools)...")
    -- --with-shared: build .so libraries (default would be static-only)
    -- --with-termlib: split out libtinfo.so so consumers can link just terminfo
    -- --without-cxx-binding: ncurses 6.4 C++ binding doesn't compile against
    --   gcc 14+ libstdc++ (NCURSES_BOOL alias for unsigned char vs std::bool
    --   in <compare>/<exception_ptr>/<type_traits>); we don't ship libncurses++
    --   anyway. Plain C ncurses is unaffected.
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --with-shared --with-termlib "
        .. "--without-cxx-binding "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local includedir = path.join(pkginfo.install_dir(), "include")
    local sys_inc = _sys_usr_includedir()

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
    if not os.isdir(sys_inc) then os.mkdir(sys_inc) end
    if os.isdir(includedir) then
        -- shell cp: os.dirs / os.files glob is unreliable in 0.4.9 sandbox.
        -- Copy every entry under include/ (subdir like ncursesw/ + flat .h)
        -- into sysroot/usr/include/.
        system.exec(string.format(
            "sh -c 'cp -rf %s/* %s/'",
            includedir, sys_inc
        ))
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

    -- ncurses ships under include/ncursesw/ + flat .h files; sweep both.
    local sys_inc = _sys_usr_includedir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/ncurses %s/ncursesw && rm -f %s/ncurses.h %s/curses.h %s/term.h %s/termcap.h %s/eti.h %s/form.h %s/menu.h %s/panel.h %s/unctrl.h 2>/dev/null || true'",
        sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc
    ))

    xvm.remove(xpkg_binding_tree)
    return true
end
