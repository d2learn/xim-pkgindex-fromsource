function __pango_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://download.gnome.org/sources/pango/%s/pango-%s.tar.xz", major_minor,
        version)
end

package = {
    homepage = "https://gitlab.gnome.org/GNOME/pango",

    -- base info
    name = "pango",
    description = "Library for layout and rendering of text with internationalization support",

    authors = "The Pango Team",
    licenses = "LGPL-2.1",
    repo = "https://gitlab.gnome.org/GNOME/pango",
    docs = "https://docs.gtk.org/Pango/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "text", "rendering", "internationalization", "gnome" },
    keywords = { "pango", "text", "layout", "rendering", "i18n", "font" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "pango-view",
        "pango-list",
        "pango-segmentation",
    },

    xpm = {
        linux = {
            deps = {
                "xpkg-helper", "gcc", "make", "meson", "ninja",
                "harfbuzz", "freetype", "fontconfig", "cairo", "gcc@11",
            },
            ["latest"] = { ref = "1.57.0" },
            ["1.57.0"] = {
                url = {
                    GLOBAL = __pango_url("1.57.0"),
                    CN = __pango_url("1.57.0"),
                },
                sha256 = nil,
            },
            ["1.56.0"] = {
                url = {
                    GLOBAL = __pango_url("1.56.0"),
                    CN = __pango_url("1.56.0"),
                },
                sha256 = nil,
            },
            ["1.55.0"] = {
                url = {
                    GLOBAL = __pango_url("1.55.0"),
                    CN = __pango_url("1.55.0"),
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

local function pango_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libpango*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libpango*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libpango-1.0.so")
        table.insert(out, "libpango-1.0.so.0")
        table.insert(out, "libpangocairo-1.0.so")
        table.insert(out, "libpangocairo-1.0.so.0")
        table.insert(out, "libpangoft2-1.0.so")
        table.insert(out, "libpangoft2-1.0.so.0")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_pango_dir = path.absolute("pango-" .. pkginfo.version())
    local build_pango_dir = "build-pango"

    log.info("1.Creating build dir -" .. build_pango_dir)
    os.tryrm(build_pango_dir)
    os.mkdir(build_pango_dir)

    log.info("2.Configuring pango with meson...")
    os.cd(build_pango_dir)
    local pango_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_pango_dir
        .. " --prefix=" .. pango_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
        .. " -Ddocumentation=false"
        .. " -Dintrospection=disabled"
        .. " -Dfontconfig=enabled"
        .. " -Dfreetype=enabled"
        .. " -Dcairo=enabled"
        .. " -Dlibthai=disabled"
        .. " -Dxft=disabled"
    )

    log.info("3.Building pango...")
    local gcc_info = xvm.info("gcc", "")
    xvm.use("gcc", "11", gcc_info)
    system.exec("ninja -j24")
    xvm.use("gcc", gcc_info["Version"])

    log.info("4.Installing pango...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "pango-binding-tree@" .. pkginfo.version()
    xvm.add("pango-binding-tree")

    log.info("Adding pango libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "pango-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(pango_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding pango programs...")
    local bin_config = {
        version = "pango-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "bin"),
        binding = version_tag,
    }

    for _, prog in ipairs(package.programs) do
        bin_config.filename = prog
        bin_config.alias = prog
        xvm.add(prog, bin_config)
    end

    log.info("Adding header files to sysroot...")
    local pango_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy pango headers
    local pango_include_dir = path.join(pango_hdr_dir, "pango-1.0")
    if os.isdir(pango_include_dir) then
        os.cp(pango_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "pango*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("pango", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("pango")

    for _, lib in ipairs(pango_libs()) do
        xvm.remove(lib, "pango-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "pango-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "pango-1.0"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "pango*.pc"))) do
        os.tryrm(pc)
    end

    xvm.remove("pango-binding-tree")

    return true
end
