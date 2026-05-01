function __libselinux_url(version)
    return format("https://github.com/SELinuxProject/selinux/releases/download/%s/libselinux-%s.tar.gz", version, version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
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

local function _ls_glob(globpat)
    local out = {}
    local h = io.popen("ls -1 " .. globpat .. " 2>/dev/null")
    if not h then return out end
    for line in h:lines() do
        if line ~= "" then table.insert(out, path.filename(line)) end
    end
    h:close()
    return out
end
local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

local function libselinux_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libselinux*.so*"))
    if #out == 0 then
        out = { "libselinux.so", "libselinux.so.1" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libselinux-" .. pkginfo.version())
    local prefix = pkginfo.install_dir()

    log.info("Building + installing libselinux (Makefile-driven, no configure)...")
    -- libselinux uses bare make + install with PREFIX vars; chain in sh -c
    -- because os.cd doesn't propagate to system.exec children.
    system.exec(string.format(
        "sh -c 'cd %s && make -j8 PREFIX=%s DESTDIR=%s LIBDIR=%s/lib INCLUDEDIR=%s/include "
        .. "&& make -j8 PREFIX=%s DESTDIR=%s LIBDIR=%s/lib INCLUDEDIR=%s/include install'",
        scode_dir,
        prefix, prefix, prefix, prefix,
        prefix, prefix, prefix, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libselinux libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local cfg = {
        type = "lib",
        version = "libselinux-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libselinux_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local sel_dir = path.join(pkginfo.install_dir(), "include", "selinux")
    if os.isdir(sel_dir) then
        os.cp(sel_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_src = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(pc_src) then
        system.exec(string.format(
            "sh -c 'cp -f %s/selinux*.pc %s/ 2>/dev/null || true'",
            pc_src, sys_pc_dir
        ))
    end

    xvm.add("libselinux")
    return true
end

function uninstall()
    xvm.remove("libselinux")
    for _, lib in ipairs(libselinux_libs()) do
        xvm.remove(lib, "libselinux-" .. pkginfo.version())
    end
    os.tryrm(path.join(_sys_usr_includedir(), "selinux"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/selinux*.pc'", _sys_usr_libdir()
    ))
    return true
end
