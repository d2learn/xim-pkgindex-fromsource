package = {
    homepage = "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/",
    name = "util-linux",
    description = "A large collection of essential low-level system utilities for Linux",
    authors = "The util-linux project",
    licenses = "GPL-2.0-or-later AND LGPL-2.1-or-later",
    repo = "https://github.com/util-linux/util-linux",

    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "system", "core-utils", "uuid", "login", "storage" },
    keywords = {
        "util-linux", "uuidgen", "libuuid", "mount", "umount", "fdisk", "lsblk",
        "login", "kill", "agetty", "dmesg", "more", "hwclock"
    },

    programs = {
        -- core
        "uuidgen", "lsblk", "fdisk", "mount", "umount", "dmesg", "hwclock",
        "kill", "more", "login", "agetty", "setterm", "ctrlaltdel", "unshare", "nsenter",
        -- others
        "getopt", "rename", "readprofile", "logger", "hexdump", "rev", "flock",
        "chfn", "chsh", "su", "newgrp", "setsid", "eject", "cal", "ionice", "script"
    },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xpkg-helper", "gcc", "make",
                "configure-project-installer",
                "linux-headers@5.11.1",
                "ncurses@6.4", -- for libtinfo
            },
            ["latest"] = { ref = "2.39.3" },
            ["2.39.3"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local libs = {
    "libuuid.so", "libuuid.so.1", "libuuid.a",
    "libmount.so", "libmount.so.1", "libmount.a",
    "libblkid.so", "libblkid.so.1", "libblkid.a",
    "libfdisk.so", "libfdisk.so.1", "libfdisk.a",
    "libsmartcols.so", "libsmartcols.so.1", "libsmartcols.a",
    "liblastlog2.so", "liblastlog2.so.1", "liblastlog2.a"
}

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")
local xpkg_binding_tree = package.name .. "-binding-tree"

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    local sudo_cmd = string.format([[sudo %s/]], system.bindir())
    system.exec(sudo_cmd .. "configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg
        -- fix not found scsi/scsi.h
        -- TODO: linux kernel headers ?
        .. " --args " .. [[ "--disable-eject" ]]
        .. " --install-by-sudo"  -- need sudo to install some files like mount/wall
    )
    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local includedir = path.join(pkginfo.install_dir(), "include")

    log.warn("Registering CLI programs...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = bindir,
            binding = binding_tree_version_tag,
        })
    end

    log.warn("Registering libraries...")
    local config = {
        type = "lib",
        version = package.name .. "-" .. pkginfo.version(),
        bindir = libdir,
        binding = binding_tree_version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("Installing headers to sysroot...")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            local name = path.filename(subdir)
            os.tryrm(path.join(sys_usr_includedir, name))
            os.cp(subdir, path.join(sys_usr_includedir, name), { force = true })
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.cp(file, sys_usr_includedir)
        end
    end

    xvm.add(package.name, { binding = binding_tree_version_tag })
    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end

    for _, lib in ipairs(libs) do
        xvm.remove(lib, package.name .. "-" .. pkginfo.version())
    end

    local includedir = path.join(pkginfo.install_dir(), "include")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(subdir)))
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(file)))
        end
    end

    xvm.remove(xpkg_binding_tree)
    return true
end