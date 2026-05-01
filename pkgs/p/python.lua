function _linux_download_url(version)
    return format("https://www.python.org/ftp/python/%s/Python-%s.tar.xz", version, version)
end

package = {
    spec = "1",

    homepage = "https://www.python.org",
    name = "python",
    description = "The Python programming language",
    maintainers = "Python Software Foundation",
    licenses = "PSF-2.0",
    repo = "https://github.com/python/cpython",
    docs = "https://docs.python.org/3",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"python", "plang", "interpreter"},
    keywords = {"python", "programming", "scripting", "language"},

    programs = {
        "python3", "pip3", "python3-config", "idle3",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xz-utils@5.4.5",
                "fromsource:libffi@3.4.4",
                "fromsource:readline@8.2",
                "fromsource:util-linux@2.39.3",     -- for libuuid
                "fromsource:openssl@3.1.5",         -- for ssl
                "fromsource:ncurses@6.4",           -- for libtinfo
                "fromsource:bzip2@1.0.8",           -- for bz2
                "fromsource:zlib@1.3.1",            -- for binascii
                -- TODO: gdbm, sqlite3, tk/tkinter
            },
            ["latest"] = { ref = "3.13.1"},
            ["3.13.1"] = { url = _linux_download_url("3.13.1"), sha256 = nil },
            ["3.12.6"] = { url = _linux_download_url("3.12.6"), sha256 = nil },
            ["3.11.11"] = { url = _linux_download_url("3.11.11"), sha256 = nil },
            ["3.10.16"] = { url = _linux_download_url("3.10.16"), sha256 = nil },
            ["3.9.21"] = { url = _linux_download_url("3.9.21"), sha256 = nil },
            ["3.8.20"] = { url = _linux_download_url("3.8.20"), sha256 = nil },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local binding_tree = "python-binding-tree"

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (os.cd doesn't propagate to system.exec children).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "Python-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-python")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()
    local syslibdir = path.join(sysroot, "lib")

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing python (autotools)...")
    -- CPPFLAGS / LDFLAGS point at the subos sysroot where the cluster-B
    -- deps (zlib, openssl, ncurses, readline, libffi, bzip2, xz-utils,
    -- util-linux/libuuid) installed their headers + libs via xvm.add. The
    -- extra -I .../usr/include/{ncurses,openssl} entries cover deps that
    -- ship under a subdir.
    -- LDFLAGS rpath points at the canonical /home/xlings/... so the produced
    -- python binary loads its shared deps from the standard xlings install
    -- layout on a user machine. TZDIR avoids test_datetime tzdata noise.
    -- Configure flags:
    --   --enable-shared:                    ship libpython3.so for embedders
    --   --with-computed-gotos:              -fno-crossjumping main loop dispatch
    --   --enable-ipv6:                      sockets v6
    --   --enable-loadable-sqlite-extensions ready for future scode:sqlite3
    --   --with-system-ffi:                  link against fromsource:libffi
    --   --without-ensurepip:                pip is added separately by xvm
    system.exec(string.format(
        "sh -c 'cd %s && "
        .. "CPPFLAGS=\"-I%s/usr/include -I%s/usr/include/ncurses -I%s/usr/include/openssl\" "
        .. "LDFLAGS=\"-L%s/lib -Wl,-rpath,/home/xlings/.xlings_data/subos/linux/lib\" "
        .. "TZDIR=/usr/share/zoneinfo "
        .. "%s/configure --prefix=%s "
        .. "--enable-shared --with-computed-gotos --enable-ipv6 "
        .. "--enable-loadable-sqlite-extensions --with-system-ffi "
        .. "&& make -j8 && make install'",
        build_dir,
        sysroot, sysroot, sysroot,
        sysroot,
        scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local python_bindir = path.join(pkginfo.install_dir(), "bin")
    local binding_root = binding_tree .. "@" .. pkginfo.version()

    xvm.add(binding_tree)

    local config = {
        bindir = python_bindir,
        binding = binding_root,
        version = "python-" .. pkginfo.version(),
        envs = {
            TZDIR = "/usr/share/zoneinfo",
            -- python manim-test.py (need LD_LIBRARY_PATH to xlings subos lib)
            -- ImportError: libstdc++.so.6: cannot open shared object file
            LD_LIBRARY_PATH = path.join(system.subos_sysrootdir(), "lib"),
        }
    }

    for _, prog in ipairs(package.programs) do
        xvm.add(prog, config)
    end

    xvm.add("python", {
        alias = "python3",
        binding = binding_root,
    })

    xvm.add("pip", {
        version = "python-" .. pkginfo.version(),
        alias = "pip3",
        binding = binding_root,
    })

    return true
end

function uninstall()
    local python_version = "python-" .. pkginfo.version()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, python_version)
    end
    xvm.remove("pip", python_version)
    xvm.remove("python")
    xvm.remove(binding_tree)
    return true
end


--[[

Historical build-time notes:

  [ERROR] readline failed to import: ... undefined symbol: UP
    -> fixed by readline-8.2 patch sequence (PR for readline)

  Optional modules that may be missing depending on what scode/fromsource
  packages are installed:

  _sqlite3
  _bz2  _curses  _curses_panel  _dbm  _gdbm  _tkinter

  Tracked under the "TODO: gdbm, sqlite3, tk/tkinter" line in deps.
]]
