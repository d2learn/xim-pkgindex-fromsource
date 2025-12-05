function __libxcb_url(version)
    return string.format("https://www.x.org/releases/individual/lib/libxcb-%s.tar.xz", version)
end

package = {
    homepage = "https://xcb.freedesktop.org/",

    -- base info
    name = "libxcb",
    description = "X protocol C-language Binding",

    authors = "The XCB Developers",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb",
    docs = "https://xcb.freedesktop.org/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "xcb" },
    keywords = { "libxcb", "xcb", "x11", "protocol" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libxcb typically has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "libxau", "libxdmcp", "xcb-proto" },
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                url = {
                    GLOBAL = __libxcb_url("1.17.0"),
                    CN = __libxcb_url("1.17.0"),
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

local function libxcb_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libxcb*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libxcb*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libxcb.so")
        table.insert(out, "libxcb.so.1")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libxcb_dir = path.absolute("libxcb-" .. pkginfo.version())
    local build_libxcb_dir = "build-libxcb"

    log.info("1.Creating build dir -" .. build_libxcb_dir)
    os.tryrm(build_libxcb_dir)
    os.mkdir(build_libxcb_dir)

    log.info("2.Configuring libxcb with autotools...")
    
    -- Set PKG_CONFIG_PATH to find xcb-proto and xorg-macros
    local sysroot_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    local sysroot_share_pc_dir = path.join(system.subos_sysrootdir(), "usr/share/pkgconfig")
    local pkg_config_path = sysroot_pc_dir .. ":" .. sysroot_share_pc_dir
    local old_pkg_config_path = os.getenv("PKG_CONFIG_PATH")
    if old_pkg_config_path then
        pkg_config_path = pkg_config_path .. ":" .. old_pkg_config_path
    end

    -- Set the environment variable for the build process
    os.setenv("PKG_CONFIG_PATH", pkg_config_path)
    
    os.cd(build_libxcb_dir)
    local libxcb_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libxcb_dir .. "/configure"
        .. " --prefix=" .. libxcb_prefix
        .. " --disable-static"
        .. " --enable-shared"
        .. " --enable-xinput"
        .. " --enable-xkb"
    )

    log.info("3.Building libxcb...")
    system.exec("make -j24")

    log.info("4.Installing libxcb...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxcb libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxcb-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxcb_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libxcb_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy xcb headers
    local xcb_include_dir = path.join(libxcb_hdr_dir, "xcb")
    if os.isdir(xcb_include_dir) then
        os.cp(xcb_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "xcb*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxcb")

    return true
end

function uninstall()
    xvm.remove("libxcb")

    for _, lib in ipairs(libxcb_libs()) do
        xvm.remove(lib, "libxcb-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "xcb"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xcb*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
