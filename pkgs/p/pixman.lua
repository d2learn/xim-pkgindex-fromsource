function __pixman_url(version)
    return format("https://cairographics.org/releases/pixman-%s.tar.gz", version)
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make", "meson", "ninja" },
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

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_pixman_dir = path.absolute("pixman-" .. pkginfo.version())
    local build_pixman_dir = "build-pixman"

    log.info("1.Creating build dir -" .. build_pixman_dir)
    os.tryrm(build_pixman_dir)
    os.mkdir(build_pixman_dir)

    log.info("2.Configuring pixman with meson...")
    os.cd(build_pixman_dir)
    local pixman_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_pixman_dir
        .. " --prefix=" .. pixman_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
    )

    log.info("3.Building pixman...")
    system.exec("ninja -j24")

    log.info("4.Installing pixman...")
    system.exec("ninja install")

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
    local pixman_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy pixman headers
    local pixman_include_dir = path.join(pixman_hdr_dir, "pixman-1")
    if os.isdir(pixman_include_dir) then
        os.cp(pixman_include_dir, sys_usr_includedir, { force = true })
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dirs = {
        path.join(pkginfo.install_dir(), "lib/pkgconfig"),
        path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu/pkgconfig"),
    }
    for _, pc_dir in ipairs(pc_dirs) do
        if os.isdir(pc_dir) then
            for _, pc in ipairs(os.files(path.join(pc_dir, "pixman-1.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
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

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "pixman-1"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "pixman-1.pc"))

    xvm.remove("pixman-binding-tree")

    return true
end
