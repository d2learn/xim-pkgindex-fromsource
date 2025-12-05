function __freetype_url(version)
    return format("https://download.savannah.gnu.org/releases/freetype/freetype-%s.tar.xz", version)
end

package = {
    homepage = "https://www.freetype.org",

    -- base info
    name = "freetype",
    description = "FreeType is a freely available software library to render fonts",

    authors = "The FreeType Team",
    licenses = "FTL or GPLv2+",
    repo = "https://git.savannah.gnu.org/cgit/freetype/freetype2.git",
    docs = "https://www.freetype.org/freetype2/docs/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "fonts", "rendering", "graphics" },
    keywords = { "freetype", "fonts", "rendering", "typography" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- freetype typically has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "meson", "ninja", "libpng", "zlib" },
            ["latest"] = { ref = "2.13.2" },
            ["2.13.2"] = {
                url = {
                    GLOBAL = __freetype_url("2.13.2"),
                    CN = __freetype_url("2.13.2"),
                },
                sha256 = nil,
            },
            ["2.12.1"] = {
                url = {
                    GLOBAL = __freetype_url("2.12.1"),
                    CN = __freetype_url("2.12.1"),
                },
                sha256 = nil,
            },
            ["2.11.1"] = {
                url = {
                    GLOBAL = __freetype_url("2.11.1"),
                    CN = __freetype_url("2.11.1"),
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

local function freetype_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    local base = "libfreetype.so"
    
    -- Scan for all libfreetype.so* files
    for _, file in ipairs(os.files(path.join(libdir, base .. "*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, base)
        table.insert(out, base .. ".6")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_freetype_dir = path.absolute("freetype-" .. pkginfo.version())
    local build_freetype_dir = "build-freetype"

    log.info("1.Creating build dir -" .. build_freetype_dir)
    os.tryrm(build_freetype_dir)
    os.mkdir(build_freetype_dir)

    log.info("2.Configuring freetype with meson...")
    os.cd(build_freetype_dir)
    local freetype_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_freetype_dir
        .. " --prefix=" .. freetype_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
        .. " -Dzlib=disabled"
        .. " -Dbzip2=disabled"
        .. " -Dpng=disabled"
        .. " -Dbrotli=disabled"
        .. " -Dharfbuzz=disabled"
    )

    log.info("3.Building freetype...")
    system.exec("ninja -j24")

    log.info("4.Installing freetype...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "freetype-binding-tree@" .. pkginfo.version()
    xvm.add("freetype-binding-tree")

    log.info("Adding freetype libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "freetype-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(freetype_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    -- no programs to register

    log.info("Adding header files to sysroot...")
    local freetype_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy freetype headers
    local freetype_include_dir = path.join(freetype_hdr_dir, "freetype2")
    if os.isdir(freetype_include_dir) then
        os.cp(freetype_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "freetype2.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("freetype", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("freetype")

    for _, lib in ipairs(freetype_libs()) do
        xvm.remove(lib, "freetype-" .. pkginfo.version())
    end

    -- no programs to remove

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "freetype2"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "freetype2.pc"))

    xvm.remove("freetype-binding-tree")

    return true
end
