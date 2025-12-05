function __libselinux_url(version)
    return format("https://github.com/SELinuxProject/selinux/releases/download/%s/libselinux-%s.tar.gz", version, version)
end

package = {
    homepage = "https://github.com/SELinuxProject/selinux",

    -- base info
    name = "libselinux",
    description = "SELinux core library",

    authors = "SELinux Project",
    licenses = "LGPL-2.1",
    repo = "https://github.com/SELinuxProject/selinux",
    docs = "https://github.com/SELinuxProject/selinux/wiki",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "security", "system", "library" },
    keywords = { "selinux", "security", "libselinux" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {},

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make" },
            ["latest"] = { ref = "3.5" },
            ["3.5"] = {
                url = {
                    GLOBAL = __libselinux_url("3.5"),
                    CN = __libselinux_url("3.5"),
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

local function libselinux_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = {}
    for _, file in ipairs(os.files(path.join(libdir, "libselinux*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    if #out == 0 then
        table.insert(out, "libselinux.so")
        table.insert(out, "libselinux.so.1")
    end
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_dir = path.absolute("libselinux-" .. pkginfo.version())
    local prefix = pkginfo.install_dir()
    
    log.info("1.Building libselinux...")
    os.cd(scode_dir)
    
    local make_cmd = "make -j24"
        .. " PREFIX=" .. prefix
        .. " DESTDIR=" .. prefix
        .. " LIBDIR=" .. path.join(prefix, "lib")
        .. " INCLUDEDIR=" .. path.join(prefix, "include")
    
    system.exec(make_cmd)
    
    log.info("2.Installing libselinux...")
    system.exec(make_cmd .. " install")
    
    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libselinux libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local config = {
        type = "lib",
        version = "libselinux-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libselinux_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end
    log.info("Adding header files to sysroot...")
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)
    local selinux_include_dir = path.join(hdr_dir, "selinux")
    if os.isdir(selinux_include_dir) then
        os.cp(selinux_include_dir, sys_usr_includedir, { force = true })
    end
    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(pc_dir) then
        for _, pc in ipairs(os.files(path.join(pc_dir, "selinux*.pc"))) do
            os.cp(pc, sys_pc_dir)
        end
    end
    xvm.add("libselinux")
    return true
end

function uninstall()
    xvm.remove("libselinux")
    for _, lib in ipairs(libselinux_libs()) do
        xvm.remove(lib, "libselinux-" .. pkginfo.version())
    end
    os.tryrm(path.join(sys_usr_includedir, "selinux"))
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "selinux*.pc"))) do
        os.tryrm(pc)
    end
    return true
end
