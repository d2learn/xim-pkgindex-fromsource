function __libpng_url(version)
    return format("https://downloads.sourceforge.net/libpng/libpng-%s.tar.xz", version)
end

package = {
    homepage = "http://www.libpng.org/pub/png/libpng.html",

    -- base info
    name = "libpng",
    description = "Official PNG reference library",

    authors = "The PNG Development Group",
    licenses = "libpng License",
    repo = "https://github.com/glennrp/libpng",
    docs = "http://www.libpng.org/pub/png/libpng-manual.txt",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "image", "png" },
    keywords = { "libpng", "png", "image", "graphics" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "pngfix",
        "png-fix-itxt",
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "zlib" },
            ["latest"] = { ref = "1.6.43" },
            ["1.6.43"] = {
                url = {
                    GLOBAL = __libpng_url("1.6.43"),
                    CN = __libpng_url("1.6.43"),
                },
                sha256 = nil,
            },
            ["1.6.42"] = {
                url = {
                    GLOBAL = __libpng_url("1.6.42"),
                    CN = __libpng_url("1.6.42"),
                },
                sha256 = nil,
            },
            ["1.6.40"] = {
                url = {
                    GLOBAL = __libpng_url("1.6.40"),
                    CN = __libpng_url("1.6.40"),
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

local libs = {
    "libpng.so",
    "libpng16.so",
    "libpng16.so.16",
}

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libpng_dir = path.absolute("libpng-" .. pkginfo.version())
    local build_libpng_dir = "build-libpng"

    log.info("1.Creating build dir -" .. build_libpng_dir)
    os.tryrm(build_libpng_dir)
    os.mkdir(build_libpng_dir)

    log.info("2.Configuring libpng...")
    os.cd(build_libpng_dir)
    local libpng_prefix = pkginfo.install_dir()
    system.exec(path.join(scode_libpng_dir, "configure")
        .. " --prefix=" .. libpng_prefix
        .. " --enable-shared"
        .. " --disable-static"
    )

    log.info("3.Building libpng...")
    system.exec("make -j24")

    log.info("4.Installing libpng...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "libpng-binding-tree@" .. pkginfo.version()
    xvm.add("libpng-binding-tree")

    log.info("Adding libpng libraries...")
    local config = {
        type = "lib",
        version = "libpng-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding libpng programs...")
    local bin_config = {
        version = "libpng-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "bin"),
        binding = version_tag,
    }

    for _, prog in ipairs(package.programs) do
        bin_config.filename = prog
        bin_config.alias = prog
        xvm.add(prog, bin_config)
    end

    log.info("Adding header files to sysroot...")
    local libpng_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy libpng16 directory
    local libpng_include_dir = path.join(libpng_hdr_dir, "libpng16")
    if os.isdir(libpng_include_dir) then
        os.cp(libpng_include_dir, sys_usr_includedir, { force = true })
    end

    -- Copy main libpng headers from include root
    for _, file in ipairs(os.files(path.join(libpng_hdr_dir, "*.h"))) do
        os.cp(file, sys_usr_includedir)
    end

    xvm.add("libpng", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("libpng")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "libpng-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "libpng-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "libpng16"))
    os.tryrm(path.join(sys_usr_includedir, "png.h"))
    os.tryrm(path.join(sys_usr_includedir, "pngconf.h"))
    os.tryrm(path.join(sys_usr_includedir, "pnglibconf.h"))

    xvm.remove("libpng-binding-tree")

    return true
end
