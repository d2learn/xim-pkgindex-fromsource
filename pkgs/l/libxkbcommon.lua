function __libxkbcommon_url(version)
    return format("https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-%s.tar.gz", version)
end

package = {
    homepage = "https://xkbcommon.org/",

    -- base info
    name = "libxkbcommon",
    description = "Keyboard layout and handling library",

    authors = "xkbcommon contributors",
    licenses = "MIT",
    repo = "https://github.com/xkbcommon/libxkbcommon",
    docs = "https://xkbcommon.org/doc/current/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "graphics", "x11", "input" },
    keywords = { "xkbcommon", "keyboard", "x11", "wayland" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {},

    xpm = {
        linux = {
            deps = {
                "xpkg-helper", "gcc", "make", "meson", "ninja",
                "libx11", "libxcb", "bison", "libxml2@latest"
            },
            ["latest"] = { ref = "1.13.1" },
            ["1.13.1"] = {
                url = __libxkbcommon_url("1.13.1"),
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

local function libxkbcommon_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = {}
    for _, file in ipairs(os.files(path.join(libdir, "libxkbcommon*.so*"))) do
        table.insert(out, path.filename(file))
    end
    if #out == 0 then
        table.insert(out, "libxkbcommon.so")
        table.insert(out, "libxkbcommon.so.0")
        table.insert(out, "libxkbcommon-x11.so")
        table.insert(out, "libxkbcommon-x11.so.0")
    end
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_dir = path.absolute("libxkbcommon-xkbcommon-" .. pkginfo.version())
    local build_dir = "build-libxkbcommon"

    log.info("1.Creating build dir -" .. build_dir)
    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("2.Configuring libxkbcommon with meson...")
    
    local sysroot = system.subos_sysrootdir()
    os.setenv("PKG_CONFIG_PATH", path.join(sysroot, "usr/lib/pkgconfig"))
    os.setenv("LD_LIBRARY_PATH", path.join(sysroot, "lib"))

    os.cd(build_dir)
    local prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_dir
        .. " --prefix=" .. prefix
        .. " --buildtype=release"
        .. " -Denable-docs=false"
        .. " -Denable-x11=true"
        .. " -Denable-wayland=false"
        -- just to avoid permission issues (bash-completion)
        .. " -Dbash-completion-path=" .. pkginfo.install_dir()
    )

    log.info("3.Building libxkbcommon...")
    system.exec("ninja -j24")

    log.info("4.Installing libxkbcommon...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxkbcommon libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib64")

    local config = {
        type = "lib",
        version = "libxkbcommon-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxkbcommon_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    local xkbcommon_include_dir = path.join(hdr_dir, "xkbcommon")
    if os.isdir(xkbcommon_include_dir) then
        os.cp(xkbcommon_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "xkbcommon*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libxkbcommon")
    return true
end

function uninstall()
    xvm.remove("libxkbcommon")

    for _, lib in ipairs(libxkbcommon_libs()) do
        xvm.remove(lib, "libxkbcommon-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "xkbcommon"))

    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "xkbcommon*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
