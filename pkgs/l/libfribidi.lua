function __libfribidi_url(version)
    return format("https://github.com/fribidi/fribidi/releases/download/v%s/fribidi-%s.tar.xz", version, version)
end

package = {
    homepage = "https://fribidi.org/",

    -- base info
    name = "libfribidi",
    description = "Free implementation of the Unicode Bidirectional Algorithm",

    authors = "Fribidi Team",
    licenses = "LGPL-2.1",
    repo = "https://github.com/fribidi/fribidi",
    docs = "https://fribidi.org/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "library", "text", "unicode" },
    keywords = { "fribidi", "bidi", "unicode", "text", "arabic", "hebrew" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "fribidi",
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "meson", "ninja" },
            ["latest"] = { ref = "1.0.13" },
            ["1.0.13"] = {
                url = {
                    GLOBAL = __libfribidi_url("1.0.13"),
                    CN = __libfribidi_url("1.0.13"),
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

local function libfribidi_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libfribidi*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libfribidi*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libfribidi.so")
        table.insert(out, "libfribidi.so.0")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_libfribidi_dir = path.absolute("fribidi-" .. pkginfo.version())
    local build_libfribidi_dir = "build-libfribidi"

    log.info("1.Creating build dir -" .. build_libfribidi_dir)
    os.tryrm(build_libfribidi_dir)
    os.mkdir(build_libfribidi_dir)

    log.info("2.Configuring libfribidi with meson...")
    
    os.setenv("PKG_CONFIG_PATH", path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig"))
    
    os.cd(build_libfribidi_dir)
    local libfribidi_prefix = pkginfo.install_dir()
    system.exec("meson setup " .. scode_libfribidi_dir
        .. " --prefix=" .. libfribidi_prefix
        .. " --buildtype=release"
        .. " -Ddocs=false"
        .. " -Dtests=false"
    )

    log.info("3.Building libfribidi...")
    system.exec("ninja -j24")

    log.info("4.Installing libfribidi...")
    system.exec("ninja install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libfribidi libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libfribidi-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libfribidi_libs()) do
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
                    version = "libfribidi-" .. pkginfo.version(),
                    bindir = bindir,
                    alias = prog,
                    filename = prog,
                })
            end
        end
    end

    log.info("Adding header files to sysroot...")
    local libfribidi_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy fribidi headers
    local fribidi_include_dir = path.join(libfribidi_hdr_dir, "fribidi")
    if os.isdir(fribidi_include_dir) then
        os.cp(fribidi_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "fribidi*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libfribidi")

    return true
end

function uninstall()
    xvm.remove("libfribidi")

    for _, lib in ipairs(libfribidi_libs()) do
        xvm.remove(lib, "libfribidi-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "libfribidi-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "fribidi"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "fribidi*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
