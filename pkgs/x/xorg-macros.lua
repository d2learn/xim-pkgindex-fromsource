function __xorg_macros_url(version)
    return format("https://www.x.org/releases/individual/util/util-macros-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "xorg-macros",
    description = "X.Org Autoconf macros",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/util/macros",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "build", "x11", "macros" },
    keywords = { "xorg-macros", "autoconf", "macros", "x11" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- no binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make" },
            ["latest"] = { ref = "1.20.1" },
            ["1.20.1"] = {
                url = {
                    GLOBAL = __xorg_macros_url("1.20.1"),
                    CN = __xorg_macros_url("1.20.1"),
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

function install()
    local scode_dir = path.absolute("util-macros-" .. pkginfo.version())
    local build_dir = "build-util-macros"

    log.info("1.Creating build dir -" .. build_dir)
    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("2.Configuring xorg-macros with autotools...")
    os.cd(build_dir)
    local prefix = pkginfo.install_dir()
    system.exec(scode_dir .. "/configure" ..
        " --prefix=" .. prefix)

    log.info("3.Building xorg-macros...")
    system.exec("make -j24")

    log.info("4.Installing xorg-macros...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xorg-macros to sysroot...")

    -- pkgconfig
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dirs = {
        path.join(pkginfo.install_dir(), "share/pkgconfig"),
        path.join(pkginfo.install_dir(), "lib/pkgconfig"),
    }
    for _, pc_dir in ipairs(pc_dirs) do
        if os.isdir(pc_dir) then
            for _, pc in ipairs(os.files(path.join(pc_dir, "xorg-macros.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    -- aclocal macros
    local sys_aclocal_dir = path.join(system.subos_sysrootdir(), "usr/share/aclocal")
    os.mkdir(sys_aclocal_dir)
    local aclocal_dir = path.join(pkginfo.install_dir(), "share/aclocal")
    if os.isdir(aclocal_dir) then
        for _, m4_file in ipairs(os.files(path.join(aclocal_dir, "*.m4"))) do
            os.cp(m4_file, sys_aclocal_dir)
        end
    end

    -- util-macros directory
    local util_dir = path.join(pkginfo.install_dir(), "share/util-macros")
    if os.isdir(util_dir) then
        os.cp(util_dir, path.join(system.subos_sysrootdir(), "usr/share"), { force = true })
    end

    xvm.add("xorg-macros")

    return true
end

function uninstall()
    xvm.remove("xorg-macros")

    -- pkgconfig
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "xorg-macros.pc"))

    -- aclocal
    local sys_aclocal_dir = path.join(system.subos_sysrootdir(), "usr/share/aclocal")
    for _, macro in ipairs({ "xorg-macros.m4", "xorgversion.m4" }) do
        os.tryrm(path.join(sys_aclocal_dir, macro))
    end

    -- util-macros dir
    os.tryrm(path.join(system.subos_sysrootdir(), "usr/share/util-macros"))

    return true
end
