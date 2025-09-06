function __glic_url(version) return format("http://ftp.gnu.org/gnu/libc/glibc-%s.tar.xz", version) end
function __glic_mirror_url(version) return format("https://ftpmirror.gnu.org/libc/glibc-%s.tar.xz", version) end

package = {
    -- base info
    name = "glibc",
    description = "GCC, the GNU Compiler Collection",

    authors = "GNU",
    licenses = "GPL",
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "language"},
    keywords = {"compiler", "gnu", "gcc", "language", "c", "c++"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "make", "gcc", "linux-headers@5.11.1" },
            ["latest"] = { ref = "2.39" },
            ["2.39"] = {
                    url = {
                        GLOBAL = __glic_url("2.39"),
                        CN = __glic_mirror_url("2.39"),
                    },
                    sha256 = nil,
            },
            ["2.38"] = {
                url = {
                    GLOBAL = __glic_url("2.38"),
                    CN = __glic_mirror_url("2.38"),
                },
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

-- libnss modules
local glibc_libs = {
    "crt1.o", "crti.o", "crtn.o", -- crt
    "ld-linux-x86-64.so.2", -- dynamic linker/loader
    "libc.so", "libc.so.6", "libc_nonshared.a", -- C library
    "libdl.so.2", -- dynamic loading
    "libm.so", "libm.so.6", "libmvec.so.1", -- math
    "libpthread.so.0", "libpthread.a", -- pthread
    "librt.so.1", -- realtime
    "libresolv.so", "libresolv.so.2", -- resolver
    -- libnss modules
    "libnss_compat.so",
    "libnss_compat.so.2",
    "libnss_dns.so.2",
    "libnss_files.so.2",
    "libnss_hesiod.so",
    "libnss_hesiod.so.2",
    "libnss_db.so",
    "libnss_db.so.2",
}

function install()

    local scode_glibc_dir = path.absolute("glibc-" .. pkginfo.version())
    local build_glibc_dir = "build-glibc"

    local linuxheader_info = xvm.info("linux-headers", "5.11.1")
    local linuxheader_dir = path.directory(linuxheader_info["SPath"])

    log.info("1.Creating build dir -" .. build_glibc_dir)
    os.tryrm(build_glibc_dir)
    os.mkdir(build_glibc_dir)

    log.info("2.Configuring glibc...")
    os.cd(build_glibc_dir)
    local glibc_prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_glibc_dir, "configure")
    system.exec(configure_file
        .. [[ --with-pkgversion="XPKG: xlings install fromsource:glibc"]]
        .. " --prefix=" .. glibc_prefix
        .. " --with-headers=" .. path.join(linuxheader_dir, "include")
        -- makedb.c:51:11: fatal error: selinux/label.h: No such file or directory
        .. " --without-selinux"
        .. " --disable-werror"
        .. " --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu"
        --.. " libc_cv_slibdir=" .. path.join(glibc_prefix, "lib64")
    )

    log.info("4.Building glibc...")
    system.exec("make -j24")

    log.info("5.Installing glibc...")
    -- TODO: use make install DESTDIR=$SYSROOT to avoid prefix hardcoding path in some files (libc.so)
    system.exec("make install")

    log.info("6.Creating lib64 symlink...")
    os.cd(glibc_prefix)
    os.ln("lib", "lib64")

    return true
end

function config()
    xvm.add("glibc")

    local glibc_root_binding = "glibc@" .. pkginfo.version()
    local glibc_version = "glibc-" .. pkginfo.version()
    local glibc_bindir = path.join(pkginfo.install_dir(), "bin")
    local glibc_libdir = path.join(pkginfo.install_dir(), "lib64")

    log.info("1 - config glibc tool...")
    local bin_config = {
        version = glibc_version,
        bindir = glibc_bindir,
        binding = glibc_root_binding,
        envs = {
            --["LD_LIBRARY_PATH"] = glibc_libdir,
            --["LD_RUN_PATH"] = glibc_libdir,
        }
    }

    xvm.add("ldd", bin_config)

-- lib
    log.info("2 - config glibc libs...")
    local lib_config = {
        version = glibc_version,
        type = "lib",
        bindir = glibc_libdir,
        binding = glibc_root_binding,
    }

    for _, lib in ipairs(glibc_libs) do
        lib_config.filename = lib -- target file name
        lib_config.alias = lib -- source file name
        xvm.add(lib, lib_config)
    end

    log.info("3 - glibc config header files...")

    __config_header()

    return true
end

function uninstall()
    local glibc_version = "glibc-" .. pkginfo.version()
    for _, lib in ipairs(glibc_libs) do
        xvm.remove(lib, glibc_version)
    end
    xvm.remove("ldd", glibc_version)
    xvm.remove("glibc")
    return true
end

-- private

function __config_header()
    local include_dir = path.join(pkginfo.install_dir(), "include")

    -- link headers to system include path
    -- TODO: add include support for xlings (use sysroot)
    local subos_sysrootdir = system.subos_sysrootdir()
    local sysroot_usrdir = path.join(subos_sysrootdir, "usr")

    log.info("Copying glibc header files to subos rootfs ...")
    os.cp(include_dir, sysroot_usrdir, {
        force = true, symlink = true
    })
    
end