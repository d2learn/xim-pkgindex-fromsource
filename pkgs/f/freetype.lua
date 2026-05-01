function __freetype_url(version)
    return format("https://download.savannah.gnu.org/releases/freetype/freetype-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
                "fromsource:libpng@1.6.43",
                "fromsource:zlib@1.3.1",
            },
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

local function freetype_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libfreetype.so*"))
    if #out == 0 then
        out = { "libfreetype.so", "libfreetype.so.6" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "freetype-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-freetype")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing freetype (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared -Dzlib=disabled -Dbzip2=disabled "
        .. "-Dpng=disabled -Dbrotli=disabled -Dharfbuzz=disabled "
        .. "&& ninja -j8 && ninja install'",
        build_dir, scode_dir, prefix
    ))

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
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local ft_dir = path.join(pkginfo.install_dir(), "include", "freetype2")
    if os.isdir(ft_dir) then
        os.cp(ft_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local pc = path.join(pkginfo.install_dir(), pc_subdir, "freetype2.pc")
        if os.isfile(pc) then
            os.cp(pc, sys_pc_dir, { force = true })
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
    os.tryrm(path.join(_sys_usr_includedir(), "freetype2"))
    os.tryrm(path.join(_sys_usr_libdir(), "pkgconfig", "freetype2.pc"))
    xvm.remove("freetype-binding-tree")
    return true
end
