function __glib_url(version)
    local major, minor = version:match("(%d+)%.(%d+)")
    return format("https://download.gnome.org/sources/glib/%s.%s/glib-%s.tar.xz", major, minor, version)
end

package = {
    spec = "1",

    homepage = "https://wiki.gnome.org/Projects/GLib",

    -- base info
    name = "glib",
    description = "Low-level core library that forms the basis of GTK+ and GNOME",

    authors = "The GNOME Project",
    licenses = "LGPL-2.1",
    repo = "https://gitlab.gnome.org/GNOME/glib",
    docs = "https://docs.gtk.org/glib/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "library", "gnome", "development" },
    keywords = { "glib", "gnome", "gtk", "gobject", "gio" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "gapplication",
        "gdbus",
        "gio",
        "glib-compile-schemas",
        "glib-compile-resources",
        "gsettings",
        "gresource",
        "gdbus-codegen",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",          -- gcc > 11 (gcc15 is ok)
                "xim:make@4.3",
                "xim:ninja@1.12.1",
                "xim:python@3.13.1",
                "fromsource:meson@1.9.1",
                "fromsource:libffi@3.4.4",
                "fromsource:zlib@1.3.1",
                "fromsource:pcre2@10.42",
            },
            ["latest"] = { ref = "2.82.2" },
            ["2.82.2"] = {
                url = {
                    GLOBAL = __glib_url("2.82.2"),
                    CN = __glib_url("2.82.2"),
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

local function glib_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    for _, prefix in ipairs({"libglib-", "libgobject-", "libgio-", "libgmodule-", "libgthread-"}) do
        for _, name in ipairs(_ls_glob(path.join(libdir, prefix .. "*.so*"))) do
            table.insert(out, name)
        end
    end
    if #out == 0 then
        out = {
            "libglib-2.0.so", "libglib-2.0.so.0",
            "libgobject-2.0.so", "libgobject-2.0.so.0",
            "libgio-2.0.so", "libgio-2.0.so.0",
            "libgmodule-2.0.so", "libgmodule-2.0.so.0",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "glib-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-glib")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing glib (meson/ninja)...")
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig:%s/usr/share/pkgconfig; "
        .. "cd %s && meson setup %s --prefix=%s --buildtype=release "
        .. "-Dman=false -Dtests=false && ninja -j8 && ninja install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding glib libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "glib-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(glib_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding programs...")
    local bindir = path.join(pkginfo.install_dir(), "bin")
    if os.isdir(bindir) then
        for _, prog in ipairs(package.programs) do
            local prog_path = path.join(bindir, prog)
            if os.isfile(prog_path) then
                xvm.add(prog, {
                    type = "bin",
                    version = "glib-" .. pkginfo.version(),
                    bindir = bindir,
                    alias = prog,
                    filename = prog,
                })
            end
        end
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local glib_dir = path.join(pkginfo.install_dir(), "include", "glib-2.0")
    if os.isdir(glib_dir) then
        os.cp(glib_dir, sys_inc, { force = true })
    end

    -- glibconfig.h from lib directory
    local glibconfig_src = path.join(libdir, "glib-2.0/include/glibconfig.h")
    if os.isfile(glibconfig_src) then
        os.cp(glibconfig_src, path.join(sys_inc, "glib-2.0/glibconfig.h"), { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            for _, glob in ipairs({"glib*.pc", "gobject*.pc", "gio*.pc", "gmodule*.pc", "gthread*.pc"}) do
                system.exec(string.format(
                    "sh -c 'cp -f %s/%s %s/ 2>/dev/null || true'",
                    src, glob, sys_pc_dir
                ))
            end
        end
    end

    xvm.add("glib")

    return true
end

function uninstall()
    xvm.remove("glib")

    for _, lib in ipairs(glib_libs()) do
        xvm.remove(lib, "glib-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "glib-" .. pkginfo.version())
    end

    os.tryrm(path.join(_sys_usr_includedir(), "glib-2.0"))
    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    system.exec(string.format(
        "sh -c 'rm -f %s/glib*.pc %s/gobject*.pc %s/gio*.pc %s/gmodule*.pc %s/gthread*.pc'",
        sys_pc_dir, sys_pc_dir, sys_pc_dir, sys_pc_dir, sys_pc_dir
    ))

    return true
end
