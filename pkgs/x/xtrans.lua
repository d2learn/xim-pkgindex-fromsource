function __xtrans_url(version)
    return string.format("https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-%s/libxtrans-xtrans-%s.tar.gz", version, version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "xtrans",
    description = "X transport library (header files only)",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxtrans",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "transport" },
    keywords = { "xtrans", "x11", "transport", "headers" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- xtrans has no binaries (only header files)
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorg-macros" },
            ["latest"] = { ref = "1.5.2" },
            ["1.5.2"] = {
                url = __xtrans_url("1.5.2"),
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

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_xtrans_dir = path.absolute("libxtrans-xtrans-" .. pkginfo.version())
    local build_xtrans_dir = "build-xtrans"

    log.info("1.Creating build dir -" .. build_xtrans_dir)
    os.tryrm(build_xtrans_dir)
    os.mkdir(build_xtrans_dir)

    log.info("2.Configuring xtrans with autotools...")

    os.setenv("ACLOCAL_PATH", path.join(system.subos_sysrootdir(), "usr/share/aclocal"))
    os.setenv("PKG_CONFIG_PATH", path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig"))

    os.cd(build_xtrans_dir)
    local xtrans_prefix = pkginfo.install_dir()
    system.exec("" .. scode_xtrans_dir .. "/autogen.sh" -- "/configure"
        .. " --prefix=" .. xtrans_prefix
    )

    log.info("3.Building xtrans...")
    system.exec("make -j24")

    log.info("4.Installing xtrans...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xtrans header files to sysroot...")
    local xtrans_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11/Xtrans headers
    local xtrans_include_dir = path.join(xtrans_hdr_dir, "X11/Xtrans")
    if os.isdir(xtrans_include_dir) then
        local x11_dir = path.join(sys_usr_includedir, "X11")
        os.mkdir(x11_dir)
        os.cp(xtrans_include_dir, x11_dir, { force = true })
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dirs = {
        path.join(pkginfo.install_dir(), "share/pkgconfig"),
        path.join(pkginfo.install_dir(), "lib/pkgconfig"),
    }
    for _, pc_dir in ipairs(pc_dirs) do
        if os.isdir(pc_dir) then
            for _, pc in ipairs(os.files(path.join(pc_dir, "xtrans.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("xtrans")

    return true
end

function uninstall()
    xvm.remove("xtrans")

    -- Remove X11/Xtrans headers
    os.tryrm(path.join(sys_usr_includedir, "X11/Xtrans"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.tryrm(path.join(sys_pc_dir, "xtrans.pc"))

    return true
end
