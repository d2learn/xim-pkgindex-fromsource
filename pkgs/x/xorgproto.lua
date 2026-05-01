function __xorgproto_url(version)
    return format("https://www.x.org/releases/individual/proto/xorgproto-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
            },
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

-- Resolve sysroot paths inside hooks (top-level eval may run before xlings
-- sets the active subos).
local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    -- Standard sandbox-fix template (see #49 bzip2):
    --   * `path.absolute` → derive from `pkginfo.install_file()`
    --   * `os.cd` doesn't propagate to system.exec children → single sh -c
    --   * `os.cpuinfo` is nil → fixed `-j8`
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "xorgproto-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-xorgproto")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing xorgproto (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'cd %s && meson setup %s --prefix=%s --buildtype=release && ninja -j8 && ninja install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xorgproto header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    local sys_lib = _sys_usr_libdir()
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_inc)

    -- Copy X11 protocol headers (literal dir, os.cp works).
    local x11_dir = path.join(hdr_dir, "X11")
    if os.isdir(x11_dir) then
        os.cp(x11_dir, sys_inc, { force = true })
    end

    -- Copy GL headers if present.
    local gl_dir = path.join(hdr_dir, "GL")
    if os.isdir(gl_dir) then
        os.cp(gl_dir, sys_inc, { force = true })
    end

    -- pkgconfig files: glob copy via shell since `os.files(glob)` is nil
    -- and `os.cp(glob,…)` silently no-ops.
    local sys_pc_dir = path.join(sys_lib, "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "share/pkgconfig"}) do
        local pc_src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(pc_src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/*.pc %s/ 2>/dev/null || true'",
                pc_src, sys_pc_dir
            ))
        end
    end

    xvm.add("xorgproto")

    return true
end

function uninstall()
    xvm.remove("xorgproto")

    -- Remove X11 protocol headers
    os.tryrm(path.join(_sys_usr_includedir(),"X11/extensions"))
    os.tryrm(path.join(_sys_usr_includedir(),"X11/dri"))
    os.tryrm(path.join(_sys_usr_includedir(),"X11/PM"))
    
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
        os.tryrm(path.join(_sys_usr_includedir(),header))
    end

    -- Remove GL headers
    os.tryrm(path.join(_sys_usr_includedir(),"GL"))

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
