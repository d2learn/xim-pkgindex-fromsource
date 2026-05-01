function __fontconfig_url(version)
    return format("https://www.freedesktop.org/software/fontconfig/release/fontconfig-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:freetype@2.13.2",
                "fromsource:expat@2.6.2",
            },
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

local function fontconfig_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libfontconfig.so*"))
    if #out == 0 then
        out = { "libfontconfig.so", "libfontconfig.so.1" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "fontconfig-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-fontconfig")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing fontconfig (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "--default-library=shared -Ddoc=disabled -Dtests=disabled -Dtools=enabled "
        .. "&& ninja -j8 && ninja install'",
        sysroot, build_dir, scode_dir, prefix
    ))

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
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local fc_dir = path.join(pkginfo.install_dir(), "include", "fontconfig")
    if os.isdir(fc_dir) then
        os.cp(fc_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local pc = path.join(pkginfo.install_dir(), pc_subdir, "fontconfig.pc")
        if os.isfile(pc) then
            os.cp(pc, sys_pc_dir, { force = true })
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
    os.tryrm(path.join(_sys_usr_includedir(), "fontconfig"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "fontconfig.pc"))

    xvm.remove("fontconfig-binding-tree")

    return true
end
