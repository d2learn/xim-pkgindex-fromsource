function __libxau_url(version)
    return format("https://www.x.org/releases/individual/lib/libXau-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorgproto@2024.1",
                "fromsource:xorg-macros@1.20.1",
            },
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

-- Sandbox file enumeration helper (os.files(glob) is sandbox-nil).
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

local function libxau_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libXau*.so*"))
    if #out == 0 then
        out = { "libXau.so", "libXau.so.6" }
    end
    return out
end

function install()
    -- sandbox template (#49 bzip2)
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libXau-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxau")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxau (autotools)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "&& make -j8 && make install'",
        system.subos_sysrootdir(), build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxau libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libxau-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxau_libs()) do
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
                "sh -c 'cp -f %s/xau*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "X11/Xauth.h"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/xau*.pc'", _sys_usr_libdir()
    ))
    return true
end
