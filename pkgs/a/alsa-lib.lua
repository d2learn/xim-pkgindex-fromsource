function __alsa_lib_url(version)
    return format("https://www.alsa-project.org/files/pub/lib/alsa-lib-%s.tar.bz2", version)
end

package = {
    homepage = "https://www.alsa-project.org/",

    -- base info
    name = "alsa-lib",
    description = "Advanced Linux Sound Architecture library",

    authors = "ALSA Project",
    licenses = "LGPL",
    repo = "https://github.com/alsa-project/alsa-lib",
    docs = "https://www.alsa-project.org/wiki/Main_Page",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "audio", "sound", "alsa" },
    keywords = { "alsa", "audio", "sound", "libasound" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {},

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make" },
            ["latest"] = { ref = "1.2.12" },
            ["1.2.12"] = {
                url = __alsa_lib_url("1.2.12"),
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

local function libasound_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = {}
    for _, file in ipairs(os.files(path.join(libdir, "libasound*.so*"))) do
        table.insert(out, path.filename(file))
    end
    if #out == 0 then
        table.insert(out, "libasound.so")
        table.insert(out, "libasound.so.2")
    end
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_dir = path.absolute("alsa-lib-" .. pkginfo.version())
    local build_dir = "build-alsa-lib"

    log.info("1.Creating build dir - " .. build_dir)
    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("2.Configuring alsa-lib...")
    os.cd(build_dir)
    local prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_dir, "configure")

    system.exec(configure_file
        .. " --prefix=" .. prefix
        .. " --enable-shared"
        .. " --disable-static"
    )

    log.info("3.Building alsa-lib...")
    system.exec("make -j24")

    log.info("4.Installing alsa-lib...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libasound libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "alsa-lib-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(libasound_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding header files to sysroot...")
    local hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    local alsa_include_dir = path.join(hdr_dir, "alsa")
    if os.isdir(alsa_include_dir) then
        os.cp(alsa_include_dir, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "alsa*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
        end
    end

    xvm.add("libasound")
    return true
end

function uninstall()
    xvm.remove("libasound")

    for _, lib in ipairs(libasound_libs()) do
        xvm.remove(lib, "alsa-lib-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "alsa"))

    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "alsa*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
