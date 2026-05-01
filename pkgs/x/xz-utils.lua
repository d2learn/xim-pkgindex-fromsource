function __xz_url(version)
    return format("https://tukaani.org/xz/xz-%s.tar.gz", version)
end

package = {
    spec = "1",

    homepage = "https://tukaani.org/xz/",

    name = "xz-utils",
    description = "XZ Utils: lossless compression software with liblzma library",

    authors = "Lasse Collin",
    licenses = "0BSD",
    repo = "https://git.tukaani.org/xz.git/",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compression"},
    keywords = {"xz", "lzma", "lib", "compression"},
    programs = { "xz", "unxz", "lzma", "unlzma", "xzcat", "lzcat" },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "5.4.5" },
            ["5.4.5"] = {
                url = __xz_url("5.4.5"),
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
    "liblzma.so",
    "liblzma.so.5",
    "liblzma.a",
}

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure+make+install in single sh -c
    -- because os.cd doesn't propagate to system.exec children.
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "xz-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-xz-utils")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing xz-utils (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

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
    local sys_inc = _sys_usr_includedir()
    local includedir = path.join(pkginfo.install_dir(), "include", "lzma")

    os.tryrm(path.join(sys_inc, "lzma"))
    os.cp(includedir, path.join(sys_inc, "lzma"), { force = true })

    -- copy lzma.h via shell (os.cd + os.cp(file, dest) pattern can mis-resolve in sandbox)
    system.exec(string.format(
        "sh -c 'cp -f %s/include/lzma.h %s/lzma.h'",
        pkginfo.install_dir(), sys_inc
    ))

    xvm.add("xz-utils", { binding = version_tag })

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
    local sys_inc = _sys_usr_includedir()
    os.tryrm(path.join(sys_inc, "lzma.h"))
    os.tryrm(path.join(sys_inc, "lzma"))

    xvm.remove("xz-utils-binding-tree")

    return true
end
