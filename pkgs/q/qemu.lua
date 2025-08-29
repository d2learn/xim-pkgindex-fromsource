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
            ["7.3.19"] = { url = qemu_url("7.3.19") },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function install()
    -- todo: fix host and workspace issues
    system.exec("xvm workspace global --active false")
        os.cd("qemu-" .. pkginfo.version())
        system.exec("./configure --prefix="
            .. pkginfo.install_dir()
            .. " --target-list=x86_64-softmmu,x86_64-linux-user"
            .. " --enable-kvm"
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