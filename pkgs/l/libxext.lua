function __libxext_url(version)
    return format("https://www.x.org/releases/individual/lib/libXext-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorgproto@2024.1",
                "fromsource:xorg-macros@1.20.1",
                "fromsource:libx11@1.8.10",
            },
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

-- Sandbox helpers (see PR #49 bzip2).
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

local function libxext_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libXext*.so*"))
    if #out == 0 then
        out = { "libXext.so", "libXext.so.6" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libXext-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxext")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxext (autotools)...")
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
    log.info("Adding libxext libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libxext-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libxext_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local x11_ext_dir = path.join(pkginfo.install_dir(), "include", "X11/extensions")
    if os.isdir(x11_ext_dir) then
        os.mkdir(path.join(sys_inc, "X11"))
        os.cp(x11_ext_dir, path.join(sys_inc, "X11/extensions"), { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/xext*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "X11/extensions"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/xext*.pc'", _sys_usr_libdir()
    ))
    return true
end
