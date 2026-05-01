function __pango_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://download.gnome.org/sources/pango/%s/pango-%s.tar.xz", major_minor,
        version)
end

package = {
    spec = "1",

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
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:gcc@11.5.0",                  -- install() switches to gcc 11 via xvm.use for the actual build; both gccs are real deps
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
                "fromsource:harfbuzz@8.3.0",
                "fromsource:freetype@2.13.2",
                "fromsource:fontconfig@2.14.2",
                "fromsource:cairo@1.18.0",
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

local function _ls_glob(globpat)
    local out = {}
    local h = io.popen("ls -1 " .. globpat .. " 2>/dev/null")
    if not h then return out end
    for line in h:lines() do
        if line ~= "" then table.insert(out, path.filename(line)) end
    end
    h:close()
    return out
end
local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

local function pango_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = _ls_glob(path.join(libdir, "libpango*.so*"))
    if #out == 0 then
        out = {
            "libpango-1.0.so", "libpango-1.0.so.0",
            "libpangocairo-1.0.so", "libpangocairo-1.0.so.0",
            "libpangoft2-1.0.so", "libpangoft2-1.0.so.0",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "pango-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-pango")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    -- gcc-11 toggle for build (kept verbatim from previous logic).
    local gcc_info = xvm.info("gcc", "")
    xvm.use("gcc", "11", gcc_info)

    log.info("Configuring + building + installing pango (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared -Ddocumentation=false -Dintrospection=disabled "
        .. "-Dfontconfig=enabled -Dfreetype=enabled -Dcairo=enabled "
        .. "-Dlibthai=disabled -Dxft=disabled "
        .. "&& ninja -j8 && ninja install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    xvm.use("gcc", gcc_info["Version"])

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
    os.mkdir(_sys_usr_includedir())

    -- Copy pango headers
    local pango_include_dir = path.join(pango_hdr_dir, "pango-1.0")
    if os.isdir(pango_include_dir) then
        os.cp(pango_include_dir, _sys_usr_includedir(), { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/pango*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "pango-1.0"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/pango*.pc'", _sys_usr_libdir()
    ))
    xvm.remove("pango-binding-tree")
    return true
end
