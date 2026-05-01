function __harfbuzz_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://github.com/harfbuzz/harfbuzz/releases/download/%s/harfbuzz-%s.tar.xz", version, version)
end

package = {
    spec = "1",

    homepage = "https://harfbuzz.github.io",

    -- base info
    name = "harfbuzz",
    description = "Text shaping engine for OpenType fonts",

    authors = "The HarfBuzz Team",
    licenses = "MIT",
    repo = "https://github.com/harfbuzz/harfbuzz",
    docs = "https://harfbuzz.github.io",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "text", "fonts", "opentype", "shaping" },
    keywords = { "harfbuzz", "text", "fonts", "opentype", "shaping" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- harfbuzz tools not installed by meson (hb-* require icu/cairo/glib)
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
                "fromsource:freetype@2.13.2",
            },
            ["latest"] = { ref = "8.3.0" },
            ["8.3.0"] = {
                url = {
                    GLOBAL = __harfbuzz_url("8.3.0"),
                    CN = __harfbuzz_url("8.3.0"),
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

local function harfbuzz_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libharfbuzz*.so*"))
    if #out == 0 then
        out = {
            "libharfbuzz.so", "libharfbuzz.so.0",
            "libharfbuzz-subset.so", "libharfbuzz-subset.so.0",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "harfbuzz-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-harfbuzz")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing harfbuzz (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared -Ddocs=disabled -Dtests=disabled "
        .. "-Dintrospection=disabled -Dglib=disabled -Dgobject=disabled -Dicu=disabled "
        .. "-Dfreetype=enabled -Dcairo=enabled "
        .. "&& ninja -j8 && ninja install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "harfbuzz-binding-tree@" .. pkginfo.version()
    xvm.add("harfbuzz-binding-tree")

    log.info("Adding harfbuzz libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "harfbuzz-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(harfbuzz_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    -- no programs to register

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local hb_dir = path.join(pkginfo.install_dir(), "include", "harfbuzz")
    if os.isdir(hb_dir) then
        os.cp(hb_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/harfbuzz*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
        end
    end

    xvm.add("harfbuzz", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("harfbuzz")

    for _, lib in ipairs(harfbuzz_libs()) do
        xvm.remove(lib, "harfbuzz-" .. pkginfo.version())
    end

    -- no programs to remove

    os.tryrm(path.join(_sys_usr_includedir(), "harfbuzz"))
    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    for _, pc in ipairs({"harfbuzz.pc", "harfbuzz-cairo.pc", "harfbuzz-subset.pc"}) do
        os.tryrm(path.join(sys_pc_dir, pc))
    end

    xvm.remove("harfbuzz-binding-tree")

    return true
end
