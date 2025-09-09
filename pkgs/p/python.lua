function _linux_download_url(version) return "https://www.python.org/ftp/python/" .. version .. "/Python-" .. version .. ".tar.xz" end

package = {
    homepage = "https://www.python.org",
    name = "python",
    description = "The Python programming language",
    maintainers = "Python Software Foundation",
    licenses = "PSF License | GPL compatible",
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
                "gcc", "make@4.3", "configure-project-installer",
                "xz-utils@5.4.5", "libffi@3.4.4", "readline@8.2",
                "util-linux@2.39.3", -- for libuuid
                "openssl@3.1.5", -- for ssl
                "ncurses@6.4", -- for libtinfo
                "bzip2@1.0.8", -- for bz2
                "zlib@1.3.1", -- for zlib needed by binascii
                -- TODO: bzip2, gdbm, qlite3, tk/tkinter
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

import("common")
import("xim.base.utils")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local binding_tree = "python-binding-tree"

function install()
    local project_dir = path.absolute("Python-" .. pkginfo.version())
    --  build args - opt or todo?
        --enable-shared
        --with-computed-gotos 
        --with-lto
        --enable-ipv6
        --enable-loadable-sqlite-extensions
    -- add rpath to fix: Following modules built successfully but were removed because they could not be imported:
    local syslibdir = path.join(system.subos_sysrootdir(), "lib")
    os.setenv("LDFLAGS", "-Wl,-rpath," .. syslibdir)
    -- fix: test test_datetime failed (tzdata)
    os.setenv("TZDIR", "/usr/share/zoneinfo")
    system.exec("configure-project-installer "
        .. pkginfo.install_dir()
        .. " --project-dir " .. project_dir
        --.. " --args " .. [["--enable-shared --enable-optimizations"]]
    )
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

[ERROR] readline failed to import: /home/xlings/.xlings_data/subos/linux/lib/libreadline.so.8: undefined symbol: UP
The following modules are *disabled* in configure script:
_sqlite3                                                                   

The necessary bits to build these optional modules were not found:
_bz2                      _curses                   _curses_panel          
_dbm                      _gdbm                     _tkinter               
To find the necessary bits, look in configure.ac and config.log.

Following modules built successfully but were removed because they could not be imported:
readline -- by patch to fix                                                                  

Checked 112 modules (33 built-in, 70 shared, 1 n/a on linux-x86_64, 1 disabled, 6 missing, 1 failed on import)


]]