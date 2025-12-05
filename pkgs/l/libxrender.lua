function __libxrender_url(version)
    return format("https://www.x.org/releases/individual/lib/libXrender-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "libxrender",
    description = "X11 rendering extension library",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxrender",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "rendering" },
    keywords = { "libxrender", "x11", "render", "extensions" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libxrender has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "xorg-macros", "libx11" },
            ["latest"] = { ref = "0.9.11" },
            ["0.9.11"] = {
                url = {
                    GLOBAL = __libxrender_url("0.9.11"),
                    CN = __libxrender_url("0.9.11"),
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

local function libxrender_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libXrender*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libXrender*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libXrender.so")
        table.insert(out, "libXrender.so.1")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libxrender_dir = path.absolute("libXrender-" .. pkginfo.version())
    local build_libxrender_dir = "build-libxrender"

    log.info("1.Creating build dir -" .. build_libxrender_dir)
    os.tryrm(build_libxrender_dir)
    os.mkdir(build_libxrender_dir)

    log.info("2.Configuring libxrender with autotools...")
    
    os.setenv("ACLOCAL_PATH", path.join(system.subos_sysrootdir(), "usr/share/aclocal"))
    os.setenv("PKG_CONFIG_PATH", path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig"))
    
    os.cd(build_libxrender_dir)
    local libxrender_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libxrender_dir .. "/configure"
        .. " --prefix=" .. libxrender_prefix
        .. " --disable-static"
        .. " --enable-shared"
    )

    log.info("3.Building libxrender...")
    system.exec("make -j24")

    log.info("4.Installing libxrender...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxrender libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxrender-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxrender_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libxrender_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 render headers
    local x11_include_dir = path.join(libxrender_hdr_dir, "X11", "extensions")
    if os.isdir(x11_include_dir) then
        os.cp(path.join(x11_include_dir, "Xrender.h"), sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "xrender*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxrender")

    return true
end

function uninstall()
    xvm.remove("libxrender")

    for _, lib in ipairs(libxrender_libs()) do
        xvm.remove(lib, "libxrender-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "Xrender.h"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xrender*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
