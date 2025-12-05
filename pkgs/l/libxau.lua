function __libxau_url(version)
    return format("https://www.x.org/releases/individual/lib/libXau-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "libxau",
    description = "X11 Authorization Protocol library",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxau",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "auth" },
    keywords = { "libxau", "x11", "authorization" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libxau has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "xorg-macros" },
            ["latest"] = { ref = "1.0.11" },
            ["1.0.11"] = {
                url = {
                    GLOBAL = __libxau_url("1.0.11"),
                    CN = __libxau_url("1.0.11"),
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

local function libxau_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libXau*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libXau*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libXau.so")
        table.insert(out, "libXau.so.6")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libxau_dir = path.absolute("libXau-" .. pkginfo.version())
    local build_libxau_dir = "build-libxau"

    log.info("1.Creating build dir -" .. build_libxau_dir)
    os.tryrm(build_libxau_dir)
    os.mkdir(build_libxau_dir)

    log.info("2.Configuring libxau with autotools...")
    os.cd(build_libxau_dir)
    local libxau_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libxau_dir .. "/configure"
        .. " --prefix=" .. libxau_prefix
        .. " --disable-static"
        .. " --enable-shared"
    )

    log.info("3.Building libxau...")
    system.exec("make -j24")

    log.info("4.Installing libxau...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxau libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxau-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxau_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libxau_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 headers
    local x11_include_dir = path.join(libxau_hdr_dir, "X11")
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "xau*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxau")

    return true
end

function uninstall()
    xvm.remove("libxau")

    for _, lib in ipairs(libxau_libs()) do
        xvm.remove(lib, "libxau-" .. pkginfo.version())
    end

    -- Remove header files (only Xauth.h)
    os.tryrm(path.join(sys_usr_includedir, "X11/Xauth.h"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xau*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
