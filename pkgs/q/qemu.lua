function qemu_url(version) return "https://download.qemu.org/qemu-" .. version .. ".tar.xz" end

package = {
    homepage = "www.qemu.org",

    -- base info
    name = "qemu",
    description = "A generic and open source machine emulator and virtualizer",

    maintainers = "abrice Bellard",
    contributors = "https://github.com/qemu/qemu/graphs/contributors",
    licenses = "Apache-2.0",
    repo = "https://github.com/qemu/qemu",
    docs = "https://www.qemu.org/documentation",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"os", "emulator"},
    keywords = {"emulator", "virtualizer"},

    programs = {
        "qemu-system-x86_64", "qemu-x86_64",
        "qemu-img", "qemu-edid", "elf2dmp", "qemu-io", "qemu-nbd",
        "qemu-pr-helper", "qemu-keymap", "qemu-vmsr-helper",
        "qemu-ga", "qemu-storage-daemon",
    },

    xpm = {
        linux = {
            deps = { "make", "ninja", "gcc" },
            ["latest"] = { ref = "10.1.0" },
            ["10.1.0"] = { url = qemu_url("10.1.0") },
            ["9.2.4"] = { url = qemu_url("9.2.4") },
            ["8.2.2"] = { url = qemu_url("8.2.2") },
            ["7.2.19"] = { url = qemu_url("7.3.19") },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()

    -- install dependencies
    -- TODO: add system name support in libxpkg
    log.warn("Installing dependencies for [ " .. linuxos.name() .. " ] ...")

    for _, dep in ipairs(__dependencies()[linuxos.name()]() or {}) do
        log.info("Installing dependency: " .. dep)
        if linuxos.name() == "debian" or linuxos.name() == "ubuntu" then
            system.exec("sudo apt-get install -y " .. dep)
        elseif linuxos.name() == "archlinux" or linuxos.name() == "manjaro" then
            system.exec("sudo pacman -S --noconfirm " .. dep)
        end
    end

    -- todo: fix host and workspace issues
    system.exec("xvm workspace global --active false")
        os.cd("qemu-" .. pkginfo.version())
        system.exec("./configure"
            .. " --prefix=" .. pkginfo.install_dir()
            -- share qemu data files
            .. " --datadir=" .. path.join(pkginfo.install_dir(), "share/qemu")
            .. " --target-list=x86_64-softmmu,x86_64-linux-user"
            .. " --enable-slirp" -- for -netdev user
            .. " --enable-vnc" -- for -vnc :0
            .. " --enable-gtk" -- for -display gtk
            .. " --enable-sdl" -- for -display sdl
            .. " --enable-opengl" -- for -display gtk,gl=on
            .. " --enable-system" -- build qemu-system-*
            .. " --enable-kvm"
            .. " --enable-virtfs" -- for -virtfs
            .. " --enable-curses" -- for -display curses
            .. " --enable-tools" -- build qemu-img and others
            .. " --enable-fdt=system" -- use system device tree
        )
        system.exec("make -j8", { retry = 3 })
        system.exec("make install")
    system.exec("xvm workspace global --active true")
    return true
end

function config()
    xvm.add("qemu", { alias = "qemu-system-x86_64" })
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = path.join(pkginfo.install_dir(), "bin"),
            binding = "qemu@" .. pkginfo.version(),
        })
    end
    return true
end

function uninstall()
    xvm.remove("qemu")
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end

-- private

function __dependencies()
    return {
        ["ubuntu"] = __debian_deps,
        ["debian"] = __debian_deps,
        ["archlinux"] = __archlinux_deps,
        ["manjaro"] = __archlinux_deps,
    }
end

function __debian_deps()
    return {
        "libfdt-dev", -- for dtb / --enable-fdt=system to fix keyboard input issue
        -- todo: verify if these are needed
        "autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev",
        "gawk build-essential bison flex texinfo gperf libtool patchutils bc",
        "zlib1g-dev libexpat-dev pkg-config  libglib2.0-dev libpixman-1-dev libsdl2-dev",
        "git tmux python3 python3-pip ninja-build",
    }
end

function __archlinux_deps()
    return {
        -- wget bridge-utils dnsmasq
        -- diffutils pkgconf which unzip util-linux dosfstools
        -- flex texinfo gmp mpfr
        -- libmpc openssl
        "wget bridge-utils dnsmasq",
        "diffutils pkgconf which unzip dosfstools",
        "flex texinfo gmp mpfr",
        "libmpc openssl", -- dtc for libfdt
        -- "util-linux" ? fdisk?
        "dtc git python ninja make gcc",
    }
end