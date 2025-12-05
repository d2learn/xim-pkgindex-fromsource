function __cairo_url(version)
    return format("https://www.cairographics.org/releases/cairo-%s.tar.xz", version)
end

package = {
    homepage = "https://cairographics.org",

    -- base info
    name = "cairo",
    description = "2D graphics library with support for multiple output devices",

    authors = "The Cairo Team",
    licenses = "LGPL-2.1 or MPL-1.1",
    repo = "https://gitlab.freedesktop.org/cairo/cairo",
    docs = "https://cairographics.org/documentation/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "rendering", "2d" },
    keywords = { "cairo", "graphics", "2d", "rendering" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "cairo-trace",
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "ninja", "freetype", "fontconfig", "libpng", "pixman" },
            ["latest"] = { ref = "1.18.0" },
            ["1.18.0"] = {
                url = {
                    GLOBAL = __cairo_url("1.18.0"),
                    CN = __cairo_url("1.18.0"),
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

local function cairo_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libcairo*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libcairo*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libcairo.so")
        table.insert(out, "libcairo.so.2")
        table.insert(out, "libcairo-script-interpreter.so")
        table.insert(out, "libcairo-script-interpreter.so.2")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_cairo_dir = path.absolute("cairo-" .. pkginfo.version())
    local build_cairo_dir = "build-cairo"

    log.info("1.Creating build dir -" .. build_cairo_dir)
    os.tryrm(build_cairo_dir)
    os.mkdir(build_cairo_dir)

    log.info("2.Configuring cairo with meson...")
    os.cd(build_cairo_dir)
    local cairo_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_cairo_dir
        .. " --prefix=" .. cairo_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
        .. " -Dtests=disabled"
        --.. " -Dglib=disabled"
        --.. " -Dxlib=disabled" -- undefined symbol: cairo_xlib_surface_get_width
        --.. " -Dxcb=disabled"
        .. " -Dquartz=disabled"
        --.. " -Dtee=disabled"
        .. " -Dpng=enabled"
        .. " -Dfreetype=enabled"
        .. " -Dfontconfig=enabled"
    )

    log.info("3.Building cairo...")
    system.exec("ninja -j24")

    log.info("4.Installing cairo...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "cairo-binding-tree@" .. pkginfo.version()
    xvm.add("cairo-binding-tree")

    log.info("Adding cairo libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "cairo-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(cairo_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding cairo programs...")
    local bin_config = {
        version = "cairo-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "bin"),
        binding = version_tag,
    }

    for _, prog in ipairs(package.programs) do
        bin_config.filename = prog
        bin_config.alias = prog
        xvm.add(prog, bin_config)
    end

    log.info("Adding header files to sysroot...")
    local cairo_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy cairo headers
    local cairo_include_dir = path.join(cairo_hdr_dir, "cairo")
    if os.isdir(cairo_include_dir) then
        os.cp(cairo_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "cairo*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("cairo", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("cairo")

    for _, lib in ipairs(cairo_libs()) do
        xvm.remove(lib, "cairo-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "cairo-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "cairo"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "cairo*.pc"))) do
        os.tryrm(pc)
    end

    xvm.remove("cairo-binding-tree")

    return true
end
