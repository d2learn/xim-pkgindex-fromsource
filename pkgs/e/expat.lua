function __expat_url(version)
    return format("https://github.com/libexpat/libexpat/releases/download/R_%s/expat-%s.tar.xz",
        version:gsub("%.", "_"), version)
end

package = {
    spec = "1",

    homepage = "https://libexpat.github.io",

    -- base info
    name = "expat",
    description = "Fast streaming XML parser library",

    authors = "The Expat Team",
    licenses = "MIT",
    repo = "https://github.com/libexpat/libexpat",
    docs = "https://libexpat.github.io/doc",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "xml", "parsing", "library" },
    keywords = { "expat", "xml", "parsing", "streaming" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "xmlwf",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "2.6.2" },
            ["2.6.2"] = {
                url = {
                    GLOBAL = __expat_url("2.6.2"),
                    CN = __expat_url("2.6.2"),
                },
                sha256 = nil,
            },
            ["2.6.1"] = {
                url = {
                    GLOBAL = __expat_url("2.6.1"),
                    CN = __expat_url("2.6.1"),
                },
                sha256 = nil,
            },
            ["2.6.0"] = {
                url = {
                    GLOBAL = __expat_url("2.6.0"),
                    CN = __expat_url("2.6.0"),
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

local function expat_libs()
    local ver = pkginfo.version()
    local major = ver:match("^(%d+)") or ver
    local minor = ver:match("^%d+%.(%d+)") or "0"
    local patch = ver:match("^%d+%.%d+%.(%d+)") or "0"
    local fullver = major .. "." .. minor .. "." .. patch
    local out = {}
    local prefix = "libexpat.so"
    table.insert(out, prefix)
    table.insert(out, prefix .. "." .. major)
    table.insert(out, prefix .. "." .. fullver)
    return out
end

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "expat-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-expat")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing expat (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --enable-shared --disable-static "
        .. "--without-docbook --without-examples --without-tests "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "expat-binding-tree@" .. pkginfo.version()
    xvm.add("expat-binding-tree")

    log.info("Adding expat libraries...")
    local config = {
        type = "lib",
        version = "expat-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = version_tag,
    }

    for _, lib in ipairs(expat_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding expat programs...")
    local bin_config = {
        version = "expat-" .. pkginfo.version(),
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
    local expat_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_inc)

    -- shell glob copy (sandbox os.files/glob-os.cp broken)
    system.exec(string.format(
        "sh -c 'cp -f %s/expat*.h %s/ 2>/dev/null || true'",
        expat_hdr_dir, sys_inc
    ))

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    local expat_pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(expat_pc_dir) then
        local pc = path.join(expat_pc_dir, "expat.pc")
        if os.isfile(pc) then
            os.cp(pc, sys_pc_dir, { force = true })
        end
    end

    xvm.add("expat", { binding = version_tag })
    return true
end

function uninstall()
    xvm.remove("expat")
    for _, lib in ipairs(expat_libs()) do
        xvm.remove(lib, "expat-" .. pkginfo.version())
    end
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "expat-" .. pkginfo.version())
    end
    local sys_inc = _sys_usr_includedir()
    for _, header in ipairs({"expat.h", "expat_config.h", "expat_external.h"}) do
        os.tryrm(path.join(sys_inc, header))
    end
    os.tryrm(path.join(_sys_usr_libdir(), "pkgconfig", "expat.pc"))
    xvm.remove("expat-binding-tree")
    return true
end
