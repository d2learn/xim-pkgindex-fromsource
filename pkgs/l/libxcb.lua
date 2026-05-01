function __libxcb_url(version)
    return string.format("https://www.x.org/releases/individual/lib/libxcb-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:xorgproto@2024.1",
                "fromsource:libxau@1.0.11",
                "fromsource:libxdmcp@1.1.5",
                "fromsource:xcb-proto@1.17.0",
            },
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

local function libxcb_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libxcb*.so*"))
    if #out == 0 then
        out = { "libxcb.so", "libxcb.so.1" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libxcb-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxcb")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxcb (autotools)...")
    -- Includes share/pkgconfig in PKG_CONFIG_PATH for xcb-proto.pc which
    -- ends up there when xcb-proto is built noarch.
    system.exec(string.format(
        "sh -c 'export ACLOCAL_PATH=%s/usr/share/aclocal; "
        .. "export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "--enable-xinput --enable-xkb && make -j8 && make install'",
        sysroot, sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxcb libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libxcb-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libxcb_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local xcb_dir = path.join(pkginfo.install_dir(), "include", "xcb")
    if os.isdir(xcb_dir) then
        os.cp(xcb_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/xcb*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "xcb"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/xcb*.pc'", _sys_usr_libdir()
    ))
    return true
end
