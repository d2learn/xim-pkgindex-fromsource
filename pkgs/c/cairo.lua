function __cairo_url(version)
    return format("https://www.cairographics.org/releases/cairo-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:freetype@2.13.2",
                "fromsource:fontconfig@2.14.2",
                "fromsource:libpng@1.6.43",
                "fromsource:pixman@0.42.2",
            },
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

local function cairo_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = _ls_glob(path.join(libdir, "libcairo*.so*"))
    if #out == 0 then
        out = {
            "libcairo.so", "libcairo.so.2",
            "libcairo-script-interpreter.so", "libcairo-script-interpreter.so.2",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "cairo-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-cairo")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing cairo (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared -Dtests=disabled -Dquartz=disabled "
        .. "-Dpng=enabled -Dfreetype=enabled -Dfontconfig=enabled "
        .. "&& ninja -j8 && ninja install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

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
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local cairo_dir = path.join(pkginfo.install_dir(), "include", "cairo")
    if os.isdir(cairo_dir) then
        os.cp(cairo_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/cairo*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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

    os.tryrm(path.join(_sys_usr_includedir(), "cairo"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/cairo*.pc'", _sys_usr_libdir()
    ))
    xvm.remove("cairo-binding-tree")

    return true
end
