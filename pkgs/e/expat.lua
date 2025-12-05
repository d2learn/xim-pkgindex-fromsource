function __expat_url(version)
    return format("https://github.com/libexpat/libexpat/releases/download/R_%s/expat-%s.tar.xz",
        version:gsub("%.", "_"), version)
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make" },
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

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_expat_dir = path.absolute("expat-" .. pkginfo.version())
    local build_expat_dir = "build-expat"

    log.info("1.Creating build dir -" .. build_expat_dir)
    os.tryrm(build_expat_dir)
    os.mkdir(build_expat_dir)

    log.info("2.Configuring expat...")
    os.cd(build_expat_dir)
    local expat_prefix = pkginfo.install_dir()
    system.exec(path.join(scode_expat_dir, "configure")
        .. " --prefix=" .. expat_prefix
        .. " --enable-shared"
        .. " --disable-static"
        .. " --without-docbook"
        .. " --without-examples"
        .. " --without-tests"
    )

    log.info("3.Building expat...")
    system.exec("make -j24")

    log.info("4.Installing expat...")
    system.exec("make install")

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
    local expat_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy all expat headers
    for _, header in ipairs(os.files(path.join(expat_hdr_dir, "expat*.h"))) do
        os.cp(header, sys_usr_includedir)
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local expat_pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(expat_pc_dir) then
        for _, pc in ipairs(os.files(path.join(expat_pc_dir, "expat.pc"))) do
            os.cp(pc, sys_pc_dir)
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

    -- Remove header files
    for _, header in ipairs({"expat.h", "expat_config.h", "expat_external.h"}) do
        os.tryrm(path.join(sys_usr_includedir, header))
    end

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "expat.pc"))

    xvm.remove("expat-binding-tree")

    return true
end
