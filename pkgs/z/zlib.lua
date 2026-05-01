function __zlib_url(version)
    return format("https://github.com/madler/zlib/releases/download/v%s/zlib-%s.tar.gz", version, version)
end

package = {
    spec = "1",

    homepage = "https://zlib.net",

    -- base info
    name = "zlib",
    description = "A Massively Spiffy Yet Delicately Unobtrusive Compression Library",

    authors = "Jean-loup Gailly, Mark Adler",
    licenses = "Zlib",
    repo = "https://github.com/madler/zlib",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = {
                url = __zlib_url("1.3.1"),
                sha256 = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23",
            },
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

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (zlib's configure does not support out-of-tree build, run from srcdir).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "zlib-" .. pkginfo.version())
    local prefix = pkginfo.install_dir()

    log.info("Configuring + building + installing zlib...")
    system.exec(string.format(
        "sh -c 'cd %s && ./configure --prefix=%s && make -j8 && make install'",
        scode_dir, prefix
    ))

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

    -- shell cp: avoid os.cd + os.cp(file, dest) sandbox edge cases
    local sys_inc = _sys_usr_includedir()
    system.exec(string.format(
        "sh -c 'cp -f %s/include/zlib.h %s/include/zconf.h %s/'",
        pkginfo.install_dir(), pkginfo.install_dir(), sys_inc
    ))

    return true
end

function uninstall()
    xvm.remove("zlib")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "zlib-" .. pkginfo.version())
    end

    local sys_inc = _sys_usr_includedir()
    os.tryrm(path.join(sys_inc, "zlib.h"))
    os.tryrm(path.join(sys_inc, "zconf.h"))

    return true
end
