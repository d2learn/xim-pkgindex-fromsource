package = {
    homepage = "https://sourceware.org/libffi/",

    name = "libffi",
    description = "Portable Foreign Function Interface Library",

    authors = "Anthony Green, Red Hat, Inc and others.",
    licenses = "https://github.com/libffi/libffi/blob/master/LICENSE",
    repo = "https://github.com/libffi/libffi",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"ffi", "system"},
    keywords = {"ffi", "lib", "ctypes", "interoperability"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make@4.3", "configure-project-installer" },
            ["latest"] = { ref = "3.4.4" },
            ["3.4.4"] = {},
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local libs = {
    "libffi.so",
    "libffi.so.8",
    "libffi.a",
}

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg)
    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "libffi-binding-tree@" .. pkginfo.version()
    xvm.add("libffi-binding-tree")

    log.warn("add libs...")
    local config = {
        type = "lib",
        version = "libffi-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib64"),
        binding = version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add header files to sysroot...")

    local ffi_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    os.cp(path.join(ffi_hdr_dir, "*"), sys_usr_includedir, { force = true })

    xvm.add("libffi", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("libffi")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "libffi-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "ffi.h"))
    os.tryrm(path.join(sys_usr_includedir, "ffitarget.h"))

    xvm.remove("libffi-binding-tree")

    return true
end