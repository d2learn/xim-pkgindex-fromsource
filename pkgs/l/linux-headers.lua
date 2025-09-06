package = {
    -- base info
    name = "linux-headers",
    description = "Linux Kernel Header",

    licenses = "GPL",
    repo = "https://github.com/torvalds/linux",

    -- xim pkg info
    type = "package",
    namespace = "scode",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "make" },
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

    os.tryrm(pkginfo.install_dir())
    os.cd("linux-" .. pkginfo.version())
    system.exec("make headers_install"
        .. " INSTALL_HDR_PATH=" .. pkginfo.install_dir()
    )

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