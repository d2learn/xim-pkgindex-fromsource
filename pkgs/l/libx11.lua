function __libx11_url(version)
    return format("https://www.x.org/releases/individual/lib/libX11-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorgproto@2024.1",
                "fromsource:xtrans@1.5.2",
                "fromsource:libxcb@1.17.0",
            },
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

local function libx11_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libX11*.so*"))
    if #out == 0 then
        out = { "libX11.so", "libX11.so.6" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libX11-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libx11")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libx11 (autotools)...")
    system.exec(string.format(
        "sh -c 'export ACLOCAL_PATH=%s/usr/share/aclocal; "
        .. "export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "&& make -j8 && make install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libx11 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libx11-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libx11_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local x11_dir = path.join(pkginfo.install_dir(), "include", "X11")
    if os.isdir(x11_dir) then
        os.cp(x11_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/x11*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "X11"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/x11*.pc'", _sys_usr_libdir()
    ))
    return true
end
