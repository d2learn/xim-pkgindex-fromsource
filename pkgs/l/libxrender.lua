function __libxrender_url(version)
    return format("https://www.x.org/releases/individual/lib/libXrender-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorgproto@2024.1",
                "fromsource:xorg-macros@1.20.1",
                "fromsource:libx11@1.8.10",
            },
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

-- Sandbox helpers (see PR #49).
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

local function libxrender_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libXrender*.so*"))
    if #out == 0 then
        out = { "libXrender.so", "libXrender.so.1" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libXrender-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxrender")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxrender (autotools)...")
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
    log.info("Adding libxrender libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libxrender-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libxrender_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local xrender_h = path.join(pkginfo.install_dir(), "include/X11/extensions/Xrender.h")
    if os.isfile(xrender_h) then
        os.cp(xrender_h, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/xrender*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "Xrender.h"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/xrender*.pc'", _sys_usr_libdir()
    ))
    return true
end
