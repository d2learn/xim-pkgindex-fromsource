function __xcb_proto_url(version)
    return string.format("https://www.x.org/releases/individual/proto/xcb-proto-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:python@3.13.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
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
    -- sandbox template (#49 bzip2)
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "xcb-proto-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-xcb-proto")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing xcb-proto (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s && make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xcb-proto data files to sysroot...")
    local sysroot = system.subos_sysrootdir()
    local sys_pc_dir = path.join(sysroot, "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)

    -- xcb-proto.pc lives in lib/pkgconfig or share/pkgconfig depending on
    -- arch detection. Use shell glob (sandbox os.files/os.cp(glob,…) are
    -- both broken). The leading-name check excludes any unrelated .pc.
    for _, pc_subdir in ipairs({"lib/pkgconfig", "share/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/xcb-proto*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
        end
    end

    -- xcb XML protocol descriptions (literal dir copy works).
    local sys_share_dir = path.join(sysroot, "usr/share")
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
    local sysroot = system.subos_sysrootdir()
    -- glob unlink via shell (sandbox os.files is nil).
    system.exec(string.format(
        "sh -c 'rm -f %s/usr/lib/pkgconfig/xcb-proto*.pc'", sysroot
    ))
    os.tryrm(path.join(sysroot, "usr/share/xcb"))
    return true
end
