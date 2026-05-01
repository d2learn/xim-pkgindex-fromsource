function __xorg_macros_url(version)
    return format("https://www.x.org/releases/individual/util/util-macros-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
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
    -- xpkg sandbox: `path.absolute` is nil → derive scode dir from
    -- `pkginfo.install_file()`. `os.cd` doesn't propagate to system.exec
    -- children → chain configure/make/make-install in a single sh -c.
    -- `os.cpuinfo` is nil → fixed -j8.
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "util-macros-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-util-macros")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing xorg-macros (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s && make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xorg-macros to sysroot...")

    -- pkgconfig: copy xorg-macros.pc out of either share/ or lib/ pkgconfig
    -- (autotools sometimes puts noarch .pc under share/, sometimes lib/).
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"share/pkgconfig", "lib/pkgconfig"}) do
        local pc_file = path.join(pkginfo.install_dir(), pc_subdir, "xorg-macros.pc")
        if os.isfile(pc_file) then
            os.cp(pc_file, sys_pc_dir, { force = true })
        end
    end

    -- aclocal macros: glob copy via shell since os.cp(glob,...) and
    -- os.files(glob) are both sandbox-nil/no-op.
    local sys_aclocal_dir = path.join(system.subos_sysrootdir(), "usr/share/aclocal")
    os.mkdir(sys_aclocal_dir)
    local aclocal_dir = path.join(pkginfo.install_dir(), "share/aclocal")
    if os.isdir(aclocal_dir) then
        system.exec(string.format(
            "sh -c 'cp -f %s/*.m4 %s/ 2>/dev/null || true'",
            aclocal_dir, sys_aclocal_dir
        ))
    end

    -- util-macros directory copy (literal dir, os.cp works)
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
