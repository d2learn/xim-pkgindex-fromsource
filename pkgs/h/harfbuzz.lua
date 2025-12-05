function __harfbuzz_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://github.com/harfbuzz/harfbuzz/releases/download/%s/harfbuzz-%s.tar.xz", version, version)
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make", "meson", "ninja", "freetype" },
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

local function harfbuzz_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libharfbuzz*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libharfbuzz*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libharfbuzz.so")
        table.insert(out, "libharfbuzz.so.0")
        table.insert(out, "libharfbuzz-subset.so")
        table.insert(out, "libharfbuzz-subset.so.0")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_harfbuzz_dir = path.absolute("harfbuzz-" .. pkginfo.version())
    local build_harfbuzz_dir = "build-harfbuzz"

    log.info("1.Creating build dir -" .. build_harfbuzz_dir)
    os.tryrm(build_harfbuzz_dir)
    os.mkdir(build_harfbuzz_dir)

    log.info("2.Configuring harfbuzz with meson...")
    os.cd(build_harfbuzz_dir)
    local harfbuzz_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_harfbuzz_dir
        .. " --prefix=" .. harfbuzz_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
        .. " -Ddocs=disabled"
        .. " -Dtests=disabled"
        .. " -Dintrospection=disabled"
        .. " -Dglib=disabled"
        .. " -Dgobject=disabled"
        .. " -Dicu=disabled"
        .. " -Dfreetype=enabled"
        .. " -Dcairo=enabled"
    )

    log.info("3.Building harfbuzz...")
    system.exec("ninja -j24")

    log.info("4.Installing harfbuzz...")
    system.exec("ninja install")

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
    local harfbuzz_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy harfbuzz headers
    local harfbuzz_include_dir = path.join(harfbuzz_hdr_dir, "harfbuzz")
    if os.isdir(harfbuzz_include_dir) then
        os.cp(harfbuzz_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "harfbuzz*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
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

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "harfbuzz"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs({"harfbuzz.pc", "harfbuzz-cairo.pc", "harfbuzz-subset.pc"}) do
        os.tryrm(path.join(sys_pc_dir, pc))
    end

    xvm.remove("harfbuzz-binding-tree")

    return true
end
