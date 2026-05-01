function __alsa_lib_url(version)
    return format("https://www.alsa-project.org/files/pub/lib/alsa-lib-%s.tar.bz2", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
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

local function libasound_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libasound*.so*"))
    if #out == 0 then
        out = { "libasound.so", "libasound.so.2" }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "alsa-lib-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-alsa-lib")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing alsa-lib (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --enable-shared --disable-static "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding libasound libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local cfg = {
        type = "lib",
        version = "alsa-lib-" .. pkginfo.version(),
        bindir = libdir,
    }
    for _, lib in ipairs(libasound_libs()) do
        cfg.alias = lib
        cfg.filename = lib
        xvm.add(lib, cfg)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local alsa_dir = path.join(pkginfo.install_dir(), "include", "alsa")
    if os.isdir(alsa_dir) then
        os.cp(alsa_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/alsa*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
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
    os.tryrm(path.join(_sys_usr_includedir(), "alsa"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/alsa*.pc'", _sys_usr_libdir()
    ))
    return true
end
