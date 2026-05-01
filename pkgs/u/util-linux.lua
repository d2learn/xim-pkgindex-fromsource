function __util_linux_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v%s/util-linux-%s.tar.xz",
        major_minor, version)
end

package = {
    spec = "1",

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
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:linux-headers@5.11.1",
                "fromsource:ncurses@6.4",       -- for libtinfo
            },
            ["latest"] = { ref = "2.39.3" },
            ["2.39.3"] = {
                url = __util_linux_url("2.39.3"),
                sha256 = nil,
            },
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

local xpkg_binding_tree = package.name .. "-binding-tree"

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (os.cd doesn't propagate to system.exec children).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "util-linux-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-util-linux")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing util-linux (autotools)...")
    -- --disable-eject: avoid scsi/scsi.h header dependency we don't ship
    -- --disable-makeinstall-chown / --disable-makeinstall-setuid: skip the
    --   chown/chmod-u+s install steps so we don't need sudo (and they're
    --   meaningless for files inside an xpkg dir that's later xvm-shimmed
    --   into subos/default/bin anyway)
    -- --without-systemd / --without-systemdsystemunitdir: skip systemd
    --   integration; xpkg sysroot has no systemd
    -- --disable-asciidoc: skip docs
    -- --disable-bash-completion: install-dist_bashcompletionDATA wants to
    --   write to /usr/share/bash-completion which is outside our prefix
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s "
        .. "--disable-eject "
        .. "--disable-makeinstall-chown --disable-makeinstall-setuid "
        .. "--without-systemd --without-systemdsystemunitdir "
        .. "--disable-asciidoc --disable-bash-completion "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local includedir = path.join(pkginfo.install_dir(), "include")
    local sys_inc = _sys_usr_includedir()

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
    if not os.isdir(sys_inc) then os.mkdir(sys_inc) end
    if os.isdir(includedir) then
        -- shell cp -r: os.dirs / os.files glob is unreliable in 0.4.9 sandbox.
        system.exec(string.format(
            "sh -c 'cp -rf %s/* %s/'",
            includedir, sys_inc
        ))
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

    -- util-linux ships include/{libmount,blkid,uuid,libsmartcols,libfdisk,...}
    -- subdirs. Sweep them via shell glob since os.dirs is unreliable.
    local sys_inc = _sys_usr_includedir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/libmount %s/blkid %s/uuid %s/libsmartcols %s/libfdisk %s/liblastlog2 2>/dev/null || true'",
        sys_inc, sys_inc, sys_inc, sys_inc, sys_inc, sys_inc
    ))

    xvm.remove(xpkg_binding_tree)
    return true
end
