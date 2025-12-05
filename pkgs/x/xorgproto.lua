function __xorgproto_url(version)
    return format("https://www.x.org/releases/individual/proto/xorgproto-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "xorgproto",
    description = "X Window System unified protocol headers",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/proto/xorgproto",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "protocol", "headers" },
    keywords = { "xorgproto", "x11", "protocol", "headers", "xproto" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- xorgproto has no binaries (only header files)
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "meson", "ninja" },
            ["latest"] = { ref = "2024.1" },
            ["2024.1"] = {
                url = {
                    GLOBAL = __xorgproto_url("2024.1"),
                    CN = __xorgproto_url("2024.1"),
                },
                sha256 = nil,
            },
            ["2023.2"] = {
                url = {
                    GLOBAL = __xorgproto_url("2023.2"),
                    CN = __xorgproto_url("2023.2"),
                },
                sha256 = nil,
            },
            ["2022.2"] = {
                url = {
                    GLOBAL = __xorgproto_url("2022.2"),
                    CN = __xorgproto_url("2022.2"),
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

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_xorgproto_dir = path.absolute("xorgproto-" .. pkginfo.version())
    local build_xorgproto_dir = "build-xorgproto"

    log.info("1.Creating build dir -" .. build_xorgproto_dir)
    os.tryrm(build_xorgproto_dir)
    os.mkdir(build_xorgproto_dir)

    log.info("2.Configuring xorgproto with meson...")
    os.cd(build_xorgproto_dir)
    local xorgproto_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_xorgproto_dir
        .. " --prefix=" .. xorgproto_prefix
        .. " --buildtype=release"
    )

    log.info("3.Building xorgproto...")
    system.exec("ninja -j24")

    log.info("4.Installing xorgproto...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xorgproto header files to sysroot...")
    local xorgproto_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 protocol headers
    local x11_include_dir = path.join(xorgproto_hdr_dir, "X11")
    if os.isdir(x11_include_dir) then
        os.cp(x11_include_dir, sys_usr_includedir, { force = true })
    end

    -- Copy GL headers if present
    local gl_include_dir = path.join(xorgproto_hdr_dir, "GL")
    if os.isdir(gl_include_dir) then
        os.cp(gl_include_dir, sys_usr_includedir, { force = true })
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dirs = {
        path.join(pkginfo.install_dir(), "lib/pkgconfig"),
        path.join(pkginfo.install_dir(), "share/pkgconfig"),
    }
    for _, pc_dir in ipairs(pc_dirs) do
        if os.isdir(pc_dir) then
            for _, pc in ipairs(os.files(path.join(pc_dir, "*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("xorgproto")

    return true
end

function uninstall()
    xvm.remove("xorgproto")

    -- Remove X11 protocol headers
    os.tryrm(path.join(sys_usr_includedir, "X11/extensions"))
    os.tryrm(path.join(sys_usr_includedir, "X11/dri"))
    os.tryrm(path.join(sys_usr_includedir, "X11/PM"))
    
    -- Remove individual X11 protocol header files
    local x11_headers = {
        "X11/ap_keysym.h", "X11/DECkeysym.h", "X11/HPkeysym.h", "X11/keysymdef.h",
        "X11/keysym.h", "X11/Sunkeysym.h", "X11/Xalloca.h", "X11/Xarch.h",
        "X11/Xatom.h", "X11/Xdefs.h", "X11/XF86keysym.h", "X11/Xfuncproto.h",
        "X11/Xfuncs.h", "X11/X.h", "X11/Xmd.h", "X11/Xosdefs.h",
        "X11/Xos.h", "X11/Xpoll.h", "X11/Xproto.h", "X11/Xprotostr.h",
        "X11/Xthreads.h", "X11/Xw32defs.h", "X11/XWDFile.h", "X11/Xwindows.h",
        "X11/Xwinsock.h",
    }
    for _, header in ipairs(x11_headers) do
        os.tryrm(path.join(sys_usr_includedir, header))
    end

    -- Remove GL headers
    os.tryrm(path.join(sys_usr_includedir, "GL"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    local proto_pcs = {
        "xproto.pc", "kbproto.pc", "inputproto.pc", "fixesproto.pc",
        "damageproto.pc", "xcmiscproto.pc", "bigreqsproto.pc", "randrproto.pc",
        "renderproto.pc", "xextproto.pc", "xf86bigfontproto.pc", "xf86dgaproto.pc",
        "xf86driproto.pc", "xf86vidmodeproto.pc", "xineramaproto.pc",
    }
    for _, pc in ipairs(proto_pcs) do
        os.tryrm(path.join(sys_pc_dir, pc))
    end

    return true
end
