function __xcb_proto_url(version)
    return string.format("https://www.x.org/releases/individual/proto/xcb-proto-%s.tar.xz", version)
end

package = {
    homepage = "https://xcb.freedesktop.org/",

    -- base info
    name = "xcb-proto",
    description = "XML-XCB protocol descriptions",

    authors = "The XCB Developers",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/proto/xcbproto",
    docs = "https://xcb.freedesktop.org/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "xcb", "protocol" },
    keywords = { "xcb-proto", "xcb", "x11", "protocol", "xml" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- xcb-proto has no user-facing binaries (only XML files)
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "python" },
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                url = __xcb_proto_url("1.17.0"),
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
    local scode_xcb_proto_dir = path.absolute("xcb-proto-" .. pkginfo.version())
    local build_xcb_proto_dir = "build-xcb-proto"

    log.info("1.Creating build dir -" .. build_xcb_proto_dir)
    os.tryrm(build_xcb_proto_dir)
    os.mkdir(build_xcb_proto_dir)

    log.info("2.Configuring xcb-proto with autotools...")
    os.cd(build_xcb_proto_dir)
    local xcb_proto_prefix = pkginfo.install_dir()
    system.exec("" .. scode_xcb_proto_dir .. "/configure"
        .. " --prefix=" .. xcb_proto_prefix
    )

    log.info("3.Building xcb-proto...")
    system.exec("make -j24")

    log.info("4.Installing xcb-proto...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xcb-proto data files to sysroot...")
    
    -- xcb-proto installs XML protocol descriptions and Python modules
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
                local filename = path.filename(pc)
                if filename:match("^xcb%-proto") then
                    os.cp(pc, sys_pc_dir)
                end
            end
        end
    end

    -- Copy xcb protocol XML files to sysroot
    local sys_share_dir = path.join(system.subos_sysrootdir(), "usr/share")
    os.mkdir(sys_share_dir)
    local xcb_share_dir = path.join(pkginfo.install_dir(), "share/xcb")
    if os.isdir(xcb_share_dir) then
        os.cp(xcb_share_dir, sys_share_dir, { force = true })
    end

    xvm.add("xcb-proto")

    return true
end

function uninstall()
    xvm.remove("xcb-proto")

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xcb-proto*.pc"))) do
        os.tryrm(pc)
    end

    -- Remove xcb protocol data files
    local sys_share_dir = path.join(system.subos_sysrootdir(), "usr/share")
    os.tryrm(path.join(sys_share_dir, "xcb"))

    return true
end
