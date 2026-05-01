function __libpng_url(version)
    return format("https://downloads.sourceforge.net/libpng/libpng-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:zlib@1.3.1",
            },
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

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libpng-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libpng")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libpng (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --enable-shared --disable-static "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

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
    local sys_inc = _sys_usr_includedir()
    local libpng_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_inc)

    -- libpng16/ subdir (literal dir, os.cp works)
    local libpng_include_dir = path.join(libpng_hdr_dir, "libpng16")
    if os.isdir(libpng_include_dir) then
        os.cp(libpng_include_dir, sys_inc, { force = true })
    end

    -- main libpng headers from include root: shell glob copy
    -- (sandbox os.files(glob) is nil; os.cp(glob,…) is silent no-op).
    system.exec(string.format(
        "sh -c 'cp -f %s/*.h %s/ 2>/dev/null || true'",
        libpng_hdr_dir, sys_inc
    ))

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
    local sys_inc = _sys_usr_includedir()
    os.tryrm(path.join(sys_inc, "libpng16"))
    os.tryrm(path.join(sys_inc, "png.h"))
    os.tryrm(path.join(sys_inc, "pngconf.h"))
    os.tryrm(path.join(sys_inc, "pnglibconf.h"))
    xvm.remove("libpng-binding-tree")
    return true
end
