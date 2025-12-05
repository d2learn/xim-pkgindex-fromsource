function __fontconfig_url(version)
    return format("https://www.freedesktop.org/software/fontconfig/release/fontconfig-%s.tar.xz", version)
end

package = {
    homepage = "https://www.freedesktop.org/wiki/Software/fontconfig",

    -- base info
    name = "fontconfig",
    description = "Library for configuring and customizing font access",

    authors = "The Fontconfig Team",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/fontconfig/fontconfig",
    docs = "https://www.freedesktop.org/software/fontconfig/fontconfig-devel/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "fonts", "configuration", "system" },
    keywords = { "fontconfig", "fonts", "configuration" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "fc-cache",
        "fc-cat",
        "fc-conflist",
        "fc-list",
        "fc-match",
        "fc-pattern",
        "fc-query",
        "fc-scan",
        "fc-validate",
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "ninja", "freetype", "expat" },
            ["latest"] = { ref = "2.14.2" },
            ["2.14.2"] = {
                url = {
                    GLOBAL = __fontconfig_url("2.14.2"),
                    CN = __fontconfig_url("2.14.2"),
                },
                sha256 = nil,
            },
            ["2.14.1"] = {
                url = {
                    GLOBAL = __fontconfig_url("2.14.1"),
                    CN = __fontconfig_url("2.14.1"),
                },
                sha256 = nil,
            },
            ["2.14.0"] = {
                url = {
                    GLOBAL = __fontconfig_url("2.14.0"),
                    CN = __fontconfig_url("2.14.0"),
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

local function fontconfig_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    local base = "libfontconfig.so"
    
    -- Scan for all libfontconfig.so* files
    for _, file in ipairs(os.files(path.join(libdir, base .. "*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, base)
        table.insert(out, base .. ".1")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_fontconfig_dir = path.absolute("fontconfig-" .. pkginfo.version())
    local build_fontconfig_dir = "build-fontconfig"

    log.info("1.Creating build dir -" .. build_fontconfig_dir)
    os.tryrm(build_fontconfig_dir)
    os.mkdir(build_fontconfig_dir)

    log.info("2.Configuring fontconfig with meson...")
    os.cd(build_fontconfig_dir)
    local fontconfig_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_fontconfig_dir
        .. " --prefix=" .. fontconfig_prefix
        .. " --buildtype=release"
        .. " --default-library=shared"
        .. " -Ddoc=disabled"
        .. " -Dtests=disabled"
        .. " -Dtools=enabled"
    )

    log.info("3.Building fontconfig...")
    system.exec("ninja -j24")

    log.info("4.Installing fontconfig...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "fontconfig-binding-tree@" .. pkginfo.version()
    xvm.add("fontconfig-binding-tree")

    log.info("Adding fontconfig libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "fontconfig-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(fontconfig_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding fontconfig programs...")
    local bin_config = {
        version = "fontconfig-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "bin"),
        binding = version_tag,
    }

    for _, prog in ipairs(package.programs) do
        bin_config.filename = prog
        bin_config.alias = prog
        xvm.add(prog, bin_config)
    end

    log.info("Adding header files to sysroot...")
    local fontconfig_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy fontconfig headers
    local fontconfig_include_dir = path.join(fontconfig_hdr_dir, "fontconfig")
    if os.isdir(fontconfig_include_dir) then
        os.cp(fontconfig_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "fontconfig.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("fontconfig", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("fontconfig")

    for _, lib in ipairs(fontconfig_libs()) do
        xvm.remove(lib, "fontconfig-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "fontconfig-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "fontconfig"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "fontconfig.pc"))

    xvm.remove("fontconfig-binding-tree")

    return true
end
