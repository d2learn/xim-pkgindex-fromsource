function __pcre2_url(version)
    return format("https://github.com/PCRE2Project/pcre2/releases/download/pcre2-%s/pcre2-%s.tar.gz", version, version)
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make", "readline", "zlib" },
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

local function pcre2_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib/x86_64-linux-gnu")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end
    
    local out = {}
    
    -- Scan for all libpcre2*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libpcre2*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- If no files found via glob, return default set
    if #out == 0 then
        table.insert(out, "libpcre2-8.so")
        table.insert(out, "libpcre2-8.so.0")
        table.insert(out, "libpcre2-posix.so")
        table.insert(out, "libpcre2-posix.so.3")
    end
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_pcre2_dir = path.absolute("pcre2-" .. pkginfo.version())
    local build_pcre2_dir = "build-pcre2"

    log.info("1.Creating build dir -" .. build_pcre2_dir)
    os.tryrm(build_pcre2_dir)
    os.mkdir(build_pcre2_dir)

    log.info("2.Configuring pcre2 with autotools...")
    
    local sysroot = system.subos_sysrootdir()
    os.setenv("ACLOCAL_PATH", path.join(sysroot, "usr/share/aclocal"))
    os.setenv("PKG_CONFIG_PATH", path.join(sysroot, "usr/lib/pkgconfig"))
    
    -- ** Cannot --enable-pcre2test-readline because readline library was not found.
    os.setenv("CPPFLAGS", "-I" .. path.join(sysroot, "usr/include"))
    --os.setenv("LDFLAGS", "-L" .. path.join(sysroot, "lib"))
    
    print(os.getenv("CPPFLAGS"))
    print(os.getenv("LDFLAGS"))

    os.cd(build_pcre2_dir)
    local pcre2_prefix = pkginfo.install_dir()
    system.exec("" .. scode_pcre2_dir .. "/configure"
        .. " --prefix=" .. pcre2_prefix
        .. " --disable-static"
        .. " --enable-shared"
        .. " --enable-pcre2-8"
        .. " --enable-pcre2-16"
        .. " --enable-pcre2-32"
        .. " --enable-pcre2grep-libz"
        .. " --enable-pcre2test-libreadline"
    )

    log.info("3.Building pcre2...")
    system.exec("make -j24")

    log.info("4.Installing pcre2...")
    system.exec("make install")

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
    local pcre2_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy pcre2 headers
    for _, header in ipairs(os.files(path.join(pcre2_hdr_dir, "pcre2*.h"))) do
        os.cp(header, sys_usr_includedir, { force = true })
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
            for _, pc in ipairs(os.files(path.join(pc_dir, "libpcre2*.pc"))) do
                os.cp(pc, sys_pc_dir)
            end
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

    -- Remove header files
    local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")
    for _, header in ipairs(os.files(path.join(sys_usr_includedir, "pcre2*.h"))) do
        os.tryrm(header)
    end

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "libpcre2*.pc"))) do
        os.tryrm(pc)
    end

    return true
end
