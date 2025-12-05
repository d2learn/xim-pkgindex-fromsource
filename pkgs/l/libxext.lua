function __libxext_url(version)
    return format("https://www.x.org/releases/individual/lib/libXext-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "libxext",
    description = "X11 miscellaneous extensions library",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxext",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "extensions" },
    keywords = { "libxext", "x11", "extensions", "misc" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libxext has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "xorg-macros", "libx11" },
            ["latest"] = { ref = "1.3.6" },
            ["1.3.6"] = {
                url = {
                    GLOBAL = __libxext_url("1.3.6"),
                    CN = __libxext_url("1.3.6"),
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

local function libxext_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libXext*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libXext*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libXext.so")
        table.insert(out, "libXext.so.6")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libxext_dir = path.absolute("libXext-" .. pkginfo.version())
    local build_libxext_dir = "build-libxext"

    log.info("1.Creating build dir -" .. build_libxext_dir)
    os.tryrm(build_libxext_dir)
    os.mkdir(build_libxext_dir)

    log.info("2.Configuring libxext with autotools...")
    
    os.setenv("ACLOCAL_PATH", path.join(system.subos_sysrootdir(), "usr/share/aclocal"))
    os.setenv("PKG_CONFIG_PATH", path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig"))
    
    os.cd(build_libxext_dir)
    local libxext_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libxext_dir .. "/configure"
        .. " --prefix=" .. libxext_prefix
        .. " --disable-static"
        .. " --enable-shared"
    )

    log.info("3.Building libxext...")
    system.exec("make -j24")

    log.info("4.Installing libxext...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxext libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxext-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxext_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libxext_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 extension headers
    local x11_include_dir = path.join(libxext_hdr_dir, "X11/extensions")
    if os.isdir(x11_include_dir) then
        local sys_ext_dir = path.join(sys_usr_includedir, "X11/extensions")
        os.mkdir(path.join(sys_usr_includedir, "X11"))
        os.cp(x11_include_dir, sys_ext_dir, { force = true })
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dirs = {
        path.join(pkginfo.install_dir(), "lib/pkgconfig"),
        path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu/pkgconfig"),
    }
    for _, pc_dir in ipairs(pc_dirs) do
        if os.isdir(pc_dir) then
            for _, pc in ipairs(os.files(path.join(pc_dir, "xext*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxext")

    return true
end

function uninstall()
    xvm.remove("libxext")

    for _, lib in ipairs(libxext_libs()) do
        xvm.remove(lib, "libxext-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "X11/extensions"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xext*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
