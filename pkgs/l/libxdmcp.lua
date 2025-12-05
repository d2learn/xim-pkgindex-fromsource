function __libxdmcp_url(version)
    return format("https://www.x.org/releases/individual/lib/libXdmcp-%s.tar.xz", version)
end

package = {
    homepage = "https://www.x.org/wiki/",

    -- base info
    name = "libxdmcp",
    description = "X Display Manager Control Protocol library",

    authors = "The X.Org Foundation",
    licenses = "MIT",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxdmcp",
    docs = "https://www.x.org/wiki/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "display" },
    keywords = { "libxdmcp", "x11", "xdm" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        -- libxdmcp has no user-facing binaries
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "xorgproto", "xorg-macros" },
            ["latest"] = { ref = "1.1.5" },
            ["1.1.5"] = {
                url = {
                    GLOBAL = __libxdmcp_url("1.1.5"),
                    CN = __libxdmcp_url("1.1.5"),
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

local function libxdmcp_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libXdmcp*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libXdmcp*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libXdmcp.so")
        table.insert(out, "libXdmcp.so.6")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libxdmcp_dir = path.absolute("libXdmcp-" .. pkginfo.version())
    local build_libxdmcp_dir = "build-libxdmcp"

    log.info("1.Creating build dir -" .. build_libxdmcp_dir)
    os.tryrm(build_libxdmcp_dir)
    os.mkdir(build_libxdmcp_dir)

    log.info("2.Configuring libxdmcp with autotools...")
    os.cd(build_libxdmcp_dir)
    local libxdmcp_prefix = pkginfo.install_dir()
    system.exec("" .. scode_libxdmcp_dir .. "/configure"
        .. " --prefix=" .. libxdmcp_prefix
        .. " --disable-static"
        .. " --enable-shared"
    )

    log.info("3.Building libxdmcp...")
    system.exec("make -j24")

    log.info("4.Installing libxdmcp...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxdmcp libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxdmcp-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxdmcp_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local libxdmcp_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy X11 headers
    local x11_include_dir = path.join(libxdmcp_hdr_dir, "X11")
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "xdmcp*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxdmcp")

    return true
end

function uninstall()
    xvm.remove("libxdmcp")

    for _, lib in ipairs(libxdmcp_libs()) do
        xvm.remove(lib, "libxdmcp-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "X11/Xdmcp.h"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xdmcp*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
