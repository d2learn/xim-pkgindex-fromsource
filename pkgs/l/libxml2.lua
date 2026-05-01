package = {
    spec = "1",

    homepage = "https://gitlab.gnome.org/GNOME/libxml2",

    -- base info
    name = "libxml2",
    description = "XML C parser and toolkit",

    authors = "GNOME/Gnome XML Library",
    licenses = "MIT",
    repo = "https://gitlab.gnome.org/GNOME/libxml2",
    docs = "https://gitlab.gnome.org/GNOME/libxml2/-/wikis/home",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "xml", "parsing", "library" },
    keywords = { "libxml2", "xml", "parser", "c" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "xml2-config",
        "xmlcatalog",
        "xmllint",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:zlib@1.3.1",
            },
            ["latest"] = { ref = "2.15.0" },
            ["2.15.0"] = {
                url = "https://github.com/GNOME/libxml2/archive/refs/tags/v2.15.0.tar.gz",
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

local function libxml2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libxml2*.so*"))
    if #out == 0 then
        out = { "libxml2.so", "libxml2.so.2" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libxml2-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libxml2")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libxml2 (autogen.sh)...")
    -- LDFLAGS rpath-link points at the active subos's lib/ so the link of
    -- xmlcatalog can find libm.so.6 there.
    system.exec(string.format(
        "sh -c 'export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "export LDFLAGS=\"-Wl,-rpath-link,%s/lib\"; "
        .. "cd %s && %s/autogen.sh --prefix=%s --enable-shared --disable-static --without-python "
        .. "&& make -j8 && make install'",
        sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxml2 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "libxml2-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libxml2_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local xml_dir = path.join(pkginfo.install_dir(), "include", "libxml2")
    if os.isdir(xml_dir) then
        os.cp(xml_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/libxml*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
        end
    end

    xvm.add("libxml2")
    return true
end

function uninstall()
    xvm.remove("libxml2")
    for _, lib in ipairs(libxml2_libs()) do
        xvm.remove(lib, "libxml2-" .. pkginfo.version())
    end
    os.tryrm(path.join(_sys_usr_includedir(), "libxml2"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/libxml*.pc'", _sys_usr_libdir()
    ))
    return true
end
