function __pcre2_url(version)
    return format("https://github.com/PCRE2Project/pcre2/releases/download/pcre2-%s/pcre2-%s.tar.gz", version, version)
end

package = {
    spec = "1",

    homepage = "https://www.pcre.org/",

    -- base info
    name = "pcre2",
    description = "Perl Compatible Regular Expressions library version 2",

    authors = "PCRE2 Team",
    licenses = "BSD",
    repo = "https://github.com/PCRE2Project/pcre2",
    docs = "https://www.pcre.org/current/doc/html/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "library", "regex", "development" },
    keywords = { "pcre2", "regex", "perl", "pattern", "matching" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "pcre2grep",
        "pcre2test",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "fromsource:readline@8.2",
                "fromsource:zlib@1.3.1",
            },
            ["latest"] = { ref = "10.42" },
            ["10.42"] = {
                url = {
                    GLOBAL = __pcre2_url("10.42"),
                    CN = __pcre2_url("10.42"),
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

local function pcre2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    local out = _ls_glob(path.join(libdir, "libpcre2*.so*"))
    if #out == 0 then
        out = {
            "libpcre2-8.so", "libpcre2-8.so.0",
            "libpcre2-posix.so", "libpcre2-posix.so.3",
        }
    end
    return out
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "pcre2-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-pcre2")
    local prefix = pkginfo.install_dir()
    local sysroot = system.subos_sysrootdir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing pcre2 (autotools)...")
    -- pcre2test-libreadline disabled because readline isn't reliably
    -- exposed via pkg-config in this env.
    system.exec(string.format(
        "sh -c 'export ACLOCAL_PATH=%s/usr/share/aclocal; "
        .. "export PKG_CONFIG_PATH=%s/usr/lib/pkgconfig; "
        .. "export CPPFLAGS=\"-I%s/usr/include\"; "
        .. "cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "--enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz "
        .. "&& make -j8 && make install'",
        sysroot, sysroot, sysroot, build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding pcre2 libraries...")
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "pcre2-" .. pkginfo.version(),
        bindir = libdir,
    }

    for _, lib in ipairs(pcre2_libs()) do
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
                    version = "pcre2-" .. pkginfo.version(),
                    bindir = bindir,
                    alias = prog,
                    filename = prog,
                })
            end
        end
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    local pcre2_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_inc)

    -- shell glob copy
    system.exec(string.format(
        "sh -c 'cp -f %s/pcre2*.h %s/ 2>/dev/null || true'",
        pcre2_hdr_dir, sys_inc
    ))

    -- pkgconfig glob copy
    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    for _, pc_subdir in ipairs({"lib/pkgconfig", "lib/x86_64-linux-gnu/pkgconfig"}) do
        local src = path.join(pkginfo.install_dir(), pc_subdir)
        if os.isdir(src) then
            system.exec(string.format(
                "sh -c 'cp -f %s/libpcre2*.pc %s/ 2>/dev/null || true'",
                src, sys_pc_dir
            ))
        end
    end
    xvm.add("pcre2")
    return true
end

function uninstall()
    xvm.remove("pcre2")
    for _, lib in ipairs(pcre2_libs()) do
        xvm.remove(lib, "pcre2-" .. pkginfo.version())
    end
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "pcre2-" .. pkginfo.version())
    end
    system.exec(string.format(
        "sh -c 'rm -f %s/pcre2*.h %s/pkgconfig/libpcre2*.pc'",
        _sys_usr_includedir(), _sys_usr_libdir()
    ))
    return true
end
