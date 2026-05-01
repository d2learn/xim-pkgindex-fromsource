function __libxkbcommon_url(version)
    return format("https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-%s.tar.gz", version)
end

package = {
    spec = "1",

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
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "fromsource:meson@1.9.1",
                "fromsource:libx11@1.8.10",
                "fromsource:libxcb@1.17.0",
                "fromsource:bison@3.8.2",
                "fromsource:libxml2@2.15.0",
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

local function libxkbcommon_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libxkbcommon*.so*"))
    if #out == 0 then
        out = {
            "libxkbcommon.so", "libxkbcommon.so.0",
            "libxkbcommon-x11.so", "libxkbcommon-x11.so.0",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libxkbcommon-xkbcommon-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxkbcommon")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxkbcommon (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "export LD_LIBRARY_PATH=%s/lib; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "-Denable-docs=false -Denable-x11=true -Denable-wayland=false "
        .. "-Dbash-completion-path=%s && ninja -j8 && ninja install'",
        sysroot, sysroot, sysroot, build_dir, scode_dir, prefix, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxkbcommon libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib64")

    local cfg = {
        type = "lib",
        version = "libxkbcommon-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libxkbcommon_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local xkb_dir = path.join(pkginfo.install_dir(), "include", "xkbcommon")
    if os.isdir(xkb_dir) then
        os.cp(xkb_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig", "lib64/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/xkbcommon*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "xkbcommon"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/xkbcommon*.pc'", _sys_usr_libdir()
    ))
    return true
end
