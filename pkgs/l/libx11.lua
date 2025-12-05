function __libx11_url(version)
    return format("https://www.x.org/releases/individual/lib/libX11-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "libx11",
    description = "X11 client-side library",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libx11",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "display" },
    keywords = { "libx11", "x11", "client", "graphics" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libx11 typically has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "xtrans", "libxcb" },
            ["latest"] = { ref = "1.8.10" },
            ["1.8.10"] = {
                url = {
                    GLOBAL = __libx11_url("1.8.10"),
                    CN = __libx11_url("1.8.10"),
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

local function libx11_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libX11*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libX11*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libX11.so")
        table.insert(out, "libX11.so.6")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libx11_dir = path.absolute("libX11-" .. pkginfo.version())
    local build_libx11_dir = "build-libx11"

    log.info("1.Creating build dir -" .. build_libx11_dir)
    os.tryrm(build_libx11_dir)
    os.mkdir(build_libx11_dir)

    log.info("2.Configuring libx11 with autotools...")
    os.cd(build_libx11_dir)
    local libx11_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libx11_dir .. "/configure"
        .. " --prefix=" .. libx11_prefix
        .. " --disable-static"
        .. " --enable-shared"
    )

    log.info("3.Building libx11...")
    system.exec("make -j24")

    log.info("4.Installing libx11...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libx11 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libx11-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libx11_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libx11_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 headers
    local x11_include_dir = path.join(libx11_hdr_dir, "X11")
    if os.isdir(x11_include_dir) then
        os.cp(x11_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "x11*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libx11")

    return true
end

function uninstall()
    xvm.remove("libx11")

    for _, lib in ipairs(libx11_libs()) do
        xvm.remove(lib, "libx11-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "X11"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "x11*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
