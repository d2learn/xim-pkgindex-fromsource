function __xtrans_url(version)
    return string.format("https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-%s/libxtrans-xtrans-%s.tar.gz", version, version)
end

package = {
    spec = "1",

    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "xtrans",
    description = "X transport library (header files only)",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxtrans",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "transport" },
    keywords = { "xtrans", "x11", "transport", "headers" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- xtrans has no binaries (only header files)
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorg-macros@1.20.1",
            },
            ["latest"] = { ref = "1.5.2" },
            ["1.5.2"] = {
                url = __xtrans_url("1.5.2"),
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

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    -- sandbox template (#49 bzip2): path.absolute / os.cd / os.cpuinfo
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libxtrans-xtrans-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-xtrans")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    -- Export ACLOCAL_PATH/PKG_CONFIG_PATH inside the sh -c so they
    -- propagate down to autoreconf / aclocal (xorg-macros.m4 lives in
    -- <sysroot>/usr/share/aclocal and must be discoverable here).
    local sysroot = system.subos_sysrootdir()

    log.info("Configuring + building + installing xtrans (autogen.sh)...")
    system.exec(string.format(
        "sh -c 'export ACLOCAL_PATH=%s/usr/share/aclocal; "
        .. "export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "cd %s && %s/autogen.sh --prefix=%s && make -j8 && make install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding xtrans header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    local sys_lib = _sys_usr_libdir()
    os.mkdir(sys_inc)

    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    local xtrans_dir = path.join(hdr_dir, "X11/Xtrans")
    if os.isdir(xtrans_dir) then
        local x11_dir = path.join(sys_inc, "X11")
        os.mkdir(x11_dir)
        os.cp(xtrans_dir, x11_dir, { force = true })
    end

    local sys_pc_dir = path.join(sys_lib, "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"share/pkgconfig", "lib/pkgconfig"}) do
        local pc_file = path.join(pkginfo.install_dir(), pc_subdir, "xtrans.pc")
        if os.isfile(pc_file) then
            os.cp(pc_file, sys_pc_dir, { force = true })
        end
    end

    xvm.add("xtrans")

    return true
end

function uninstall()
    xvm.remove("xtrans")
    os.tryrm(path.join(_sys_usr_includedir(), "X11/Xtrans"))
    os.tryrm(path.join(_sys_usr_libdir(), "pkgconfig", "xtrans.pc"))
    return true
end
