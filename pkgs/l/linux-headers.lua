package = {
    spec = "1",

    -- base info
    name = "linux-headers",
    description = "Linux Kernel Header",

    licenses = "GPL",
    repo = "https://github.com/torvalds/linux",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:make@4.3" },
            ["latest"] = { ref = "5.11.1" },
            ["5.11.1"] = {
                url = "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.11.1.tar.gz",
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    -- xpkg sandbox: `os.cd` does not propagate into `system.exec` children,
    -- so use `make -C <dir>` to set the build directory explicitly.
    local scode_dir = path.join(
        path.directory(pkginfo.install_file()),
        "linux-" .. pkginfo.version()
    )

    os.tryrm(pkginfo.install_dir())
    system.exec(string.format(
        "make -C %s headers_install INSTALL_HDR_PATH=%s",
        scode_dir, pkginfo.install_dir()
    ))

    log.info("Copying linux header files to subos rootfs ...")
    local sysroot_usrdir = path.join(system.subos_sysrootdir(), "usr")
    if not os.isdir(sysroot_usrdir) then
        os.mkdir(sysroot_usrdir)
    end
    os.cp(path.join(pkginfo.install_dir(), "include"), sysroot_usrdir, {
        force = true, symlink = true
    })

    xvm.add("linux-headers")

    return true
end

function uninstall()
    xvm.remove("linux-headers")
    return true
end