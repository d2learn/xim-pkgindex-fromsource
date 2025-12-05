function __glib_url(version)
    local major, minor = version:match("(%d+)%.(%d+)")
    return format("https://download.gnome.org/sources/glib/%s.%s/glib-%s.tar.xz", major, minor, version)
end

package = {
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
                "xpkg-helper", "gcc", -- gcc > 11 (gcc15 is ok)
                "make", "meson", "ninja", "python", "libffi", "zlib", "pcre2"
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

local function glib_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all glib*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libglib-*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    for _, file in ipairs(os.files(path.join(libdir, "libgobject-*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    for _, file in ipairs(os.files(path.join(libdir, "libgio-*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    for _, file in ipairs(os.files(path.join(libdir, "libgmodule-*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    for _, file in ipairs(os.files(path.join(libdir, "libgthread-*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libglib-2.0.so")
        table.insert(out, "libglib-2.0.so.0")
        table.insert(out, "libgobject-2.0.so")
        table.insert(out, "libgobject-2.0.so.0")
        table.insert(out, "libgio-2.0.so")
        table.insert(out, "libgio-2.0.so.0")
        table.insert(out, "libgmodule-2.0.so")
        table.insert(out, "libgmodule-2.0.so.0")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_glib_dir = path.absolute("glib-" .. pkginfo.version())
    local build_glib_dir = "build-glib"

    log.info("1.Creating build dir -" .. build_glib_dir)
    os.tryrm(build_glib_dir)
    os.mkdir(build_glib_dir)

    log.info("2.Configuring glib with meson...")
    
    os.setenv("PKG_CONFIG_PATH", path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig"))
    
    os.cd(build_glib_dir)
    local glib_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_glib_dir
        .. " --prefix=" .. glib_prefix
        .. " --buildtype=release"
        .. " -Dman=false"
        .. " -Dtests=false"
    )

    log.info("3.Building glib...")
    system.exec("ninja -j24")

    log.info("4.Installing glib...")
    system.exec("ninja install")

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
    local glib_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy glib-2.0 headers
    local glib_include_dir = path.join(glib_hdr_dir, "glib-2.0")
    if os.isdir(glib_include_dir) then
        os.cp(glib_include_dir, sys_usr_includedir, { force = true })
    end

    -- Copy glibconfig.h from lib directory
    local glibconfig_src = path.join(libdir, "glib-2.0/include/glibconfig.h")
    if os.isfile(glibconfig_src) then
        local glibconfig_dst = path.join(sys_usr_includedir, "glib-2.0/glibconfig.h")
        os.cp(glibconfig_src, glibconfig_dst, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "glib*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
            for _, pc in ipairs(os.files(path.join(pc_dir, "gobject*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
            for _, pc in ipairs(os.files(path.join(pc_dir, "gio*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
            for _, pc in ipairs(os.files(path.join(pc_dir, "gmodule*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
            for _, pc in ipairs(os.files(path.join(pc_dir, "gthread*.pc"))) do
                os.cp(pc, sys_pc_dir)
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

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "glib-2.0"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pattern in ipairs({"glib*.pc", "gobject*.pc", "gio*.pc", "gmodule*.pc", "gthread*.pc"}) do
        for _, pc in ipairs(os.files(path.join(sys_pc_dir, pattern))) do
            os.tryrm(pc)
        end
    end

    return true
end
