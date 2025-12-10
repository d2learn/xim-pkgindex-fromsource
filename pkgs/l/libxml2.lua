package = {
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
            deps = { "xpkg-helper", "gcc", "make", "zlib" },
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

local function libxml2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = {}
    for _, file in ipairs(os.files(path.join(libdir, "libxml2*.so*"))) do
        table.insert(out, path.filename(file))
    end
    if #out == 0 then
        table.insert(out, "libxml2.so")
        table.insert(out, "libxml2.so.2")
    end
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_dir = path.absolute("libxml2-" .. pkginfo.version())
    local build_dir = "build-libxml2"

    log.info("1.Creating build dir - " .. build_dir)
    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("2.Configuring libxml2...")
    os.cd(build_dir)
    local prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_dir, "autogen.sh")

    os.setenv("LDFLAGS", "-Wl,-rpath,/home/xlings/.xlings_data/subos/linux/lib")
    -- add rpath link to LDFLAGS
    --   CCLD     xmlcatalog
    -- ld: warning: libm.so.6, needed by ./.libs/libxml2.so, not found (try using -rpath or -rpath-link)
    os.addenv("LDFLAGS", " -Wl,-rpath-link," .. path.join(system.subos_sysrootdir(), "lib"))

    system.exec(configure_file
        .. " --prefix=" .. prefix
        .. " --enable-shared"
        .. " --disable-static"
        --.. " --with-zlib" -- TODO: enable zlib support
        .. " --without-python"
    )

    log.info("3.Building libxml2...")
    system.exec("make -j24")

    log.info("4.Installing libxml2...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libxml2 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libxml2-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libxml2_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    local xml_include_dir = path.join(hdr_dir, "libxml2")
    if os.isdir(xml_include_dir) then
        os.cp(xml_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "libxml*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
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

    os.tryrm(path.join(sys_usr_includedir, "libxml2"))

    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "libxml*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
