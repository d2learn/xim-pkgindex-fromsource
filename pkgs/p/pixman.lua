function __pixman_url(version)
    return format("https://cairographics.org/releases/pixman-%s.tar.gz", version)
end

package = {
    spec = "1",

    homepage = "https://cairographics.org",

    -- base info
    name = "pixman",
    description = "Low-level software library for pixel manipulation",

    authors = "The Pixman Team",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/pixman/pixman",
    docs = "https://cairographics.org/documentation/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "pixel", "rendering" },
    keywords = { "pixman", "graphics", "pixel", "rendering" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- pixman typically installs no user-facing binaries; keep empty
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
            },
            ["latest"] = { ref = "0.42.2" },
            ["0.42.2"] = {
                url = {
                    GLOBAL = __pixman_url("0.42.2"),
                    CN = __pixman_url("0.42.2"),
                },
                sha256 = nil,
            },
            ["0.42.0"] = {
                url = {
                    GLOBAL = __pixman_url("0.42.0"),
                    CN = __pixman_url("0.42.0"),
                },
                sha256 = nil,
            },
            ["0.40.0"] = {
                url = {
                    GLOBAL = __pixman_url("0.40.0"),
                    CN = __pixman_url("0.40.0"),
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

local function pixman_libs()
    local ver = pkginfo.version()
    local major = ver:match("^(%d+)") or ver
    local major_minor = ver:match("^(%d+%.%d+)") or major
    local out = {}
    local prefix = "libpixman-1.so"
    table.insert(out, prefix)
    table.insert(out, prefix .. "." .. major)
    --table.insert(out, prefix .. "." .. major_minor)
    table.insert(out, prefix .. "." .. ver)
    return out
end

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "pixman-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-pixman")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing pixman (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared && ninja -j8 && ninja install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "pixman-binding-tree@" .. pkginfo.version()
    xvm.add("pixman-binding-tree")

    log.info("Adding pixman libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "pixman-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(pixman_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    -- no programs to register

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local pix_dir = path.join(pkginfo.install_dir(), "include", "pixman-1")
    if os.isdir(pix_dir) then
        os.cp(pix_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local pc = path.join(pkginfo.install_dir(), pc_subdir, "pixman-1.pc")
        if os.isfile(pc) then
            os.cp(pc, sys_pc_dir, { force = true })
        end
    end

    xvm.add("pixman", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("pixman")

    for _, lib in ipairs(pixman_libs()) do
        xvm.remove(lib, "pixman-" .. pkginfo.version())
    end

    -- no programs to remove

    os.tryrm(path.join(_sys_usr_includedir(), "pixman-1"))
    os.tryrm(path.join(_sys_usr_libdir(), "pkgconfig", "pixman-1.pc"))
    xvm.remove("pixman-binding-tree")

    return true
end
