function __readline_url(version)
    return format("https://ftpmirror.gnu.org/gnu/readline/readline-%s.tar.gz", version)
end

package = {
    spec = "1",

    homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html",

    name = "readline",
    description = "GNU Readline Library for Command-line Editing",

    authors = "Chet Ramey",
    licenses = "GPL-3.0",
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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:make@4.3",
                "xim:gcc@11.5.0",                  -- readline 8.2 wants gcc < 15
                "fromsource:ncurses@6.4",          -- shared termcap library
            },
            ["latest"] = { ref = "8.2" },
            ["8.2"] = {
                url = __readline_url("8.2"),
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
import("xim.libxpkg.utils")

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

local function readline_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local out = {}
    for _, name in ipairs(_ls_glob(path.join(libdir, "libreadline*.so*"))) do
        table.insert(out, name)
    end
    for _, name in ipairs(_ls_glob(path.join(libdir, "libhistory*.so*"))) do
        table.insert(out, name)
    end
    table.insert(out, "libreadline.a")
    table.insert(out, "libhistory.a")
    return out
end

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain patch-fetch + patch-apply + configure
    -- + make + install in a single sh -c (os.cd doesn't propagate; we have
    -- 13 upstream readline patches to fetch and apply before configure).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "readline-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-readline")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Re-extracting source, downloading + applying upstream readline-8.2 patches 001..013, then build...")
    -- We re-extract from the tarball into runtime_dir so the source is a
    -- pristine patchlevel=0 every time install() runs. xlings's own extract
    -- step is a one-shot on first download; if a previous install attempt
    -- left the source dir partially patched, xlings does not re-extract on
    -- the next attempt — so we do it ourselves here. Then fetch + apply the
    -- 13 upstream patches and build out-of-tree.
    --
    -- CPPFLAGS / LDFLAGS point at the subos sysroot where xim:ncurses.config()
    -- placed its libtinfo / libncurses headers + libs (xvm.add registers
    -- shims under subos/{lib,usr/include}). Without these, configure's
    -- -ltinfo / -ltermcap probe fails and readline falls back to stub
    -- declarations of tputs/tgoto with empty arglists, which then
    -- mismatch the call sites in display.c (`too many arguments to
    -- function 'tgoto'`).
    local tarball = pkginfo.install_file()
    local sysroot = system.subos_sysrootdir()
    -- ftp.gnu.org direct (ftpmirror.gnu.org load-balances and occasionally
    -- 404s on individual patches between rotations; canonical source is stable).
    local patch_base = "https://ftp.gnu.org/gnu/readline/readline-" .. pkginfo.version() .. "-patches"
    system.exec(string.format(
        "sh -c 'set -e; cd %s && rm -rf %s && tar -xf %s "
        .. "&& cd %s "
        .. "&& for i in 001 002 003 004 005 006 007 008 009 010 011 012 013; do "
        .. "    curl -sLf -O %s/readline82-$i; "
        .. "    patch -p0 -i readline82-$i; "
        .. "  done "
        .. "&& cd %s "
        .. "&& CPPFLAGS=\"-I%s/usr/include -I%s/usr/include/ncurses\" "
        .. "LDFLAGS=\"-L%s/lib -Wl,-rpath,/home/xlings/.xlings_data/subos/linux/lib\" "
        .. "%s/configure --prefix=%s --enable-shared --with-shared-termcap-library --with-curses "
        .. "&& make -j8 && make install'",
        runtime_dir, scode_dir, tarball,
        scode_dir, patch_base,
        build_dir,
        sysroot, sysroot, sysroot,
        scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "readline-binding-tree@" .. pkginfo.version()
    xvm.add("readline-binding-tree")

    log.warn("add libs...")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local cfg = {
        type = "lib",
        version = "readline-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(readline_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.warn("add header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    if not os.isdir(sys_inc) then os.mkdir(sys_inc) end
    local hdr_dir = path.join(pkginfo.install_dir(), "include", "readline")
    if os.isdir(hdr_dir) then
        os.cp(hdr_dir, path.join(sys_inc, "readline"), { force = true })
    end

    log.warn("add pkgconfig files to sysroot...")
    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    if not os.isdir(sys_pc_dir) then os.mkdir(sys_pc_dir) end
    -- shell cp glob: os.files(*.pc) is unreliable in 0.4.9 sandbox
    system.exec(string.format(
        "sh -c 'cp -f %s/lib/pkgconfig/readline*.pc %s/lib/pkgconfig/history*.pc %s/ 2>/dev/null || true'",
        pkginfo.install_dir(), pkginfo.install_dir(), sys_pc_dir
    ))

    xvm.add("readline", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("readline")

    for _, lib in ipairs(readline_libs()) do
        xvm.remove(lib, "readline-" .. pkginfo.version())
    end

    local sys_inc = _sys_usr_includedir()
    os.tryrm(path.join(sys_inc, "readline"))

    -- Remove pkgconfig files via shell glob
    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    system.exec(string.format(
        "sh -c 'rm -f %s/readline*.pc %s/history*.pc 2>/dev/null || true'",
        sys_pc_dir, sys_pc_dir
    ))

    xvm.remove("readline-binding-tree")

    return true
end
