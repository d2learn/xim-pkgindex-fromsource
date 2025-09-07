function __glic_url(version) return format("https://ftp.gnu.org/gnu/binutils/binutils-%s.tar.gz", version) end
function __glic_mirror_url(version) return format("https://ftpmirror.gnu.org/gnu/binutils/binutils-%s.tar.xz", version) end

package = {
    homepage = "https://www.gnu.org/software/binutils",
    -- base info
    name = "binutils",
    description = "The GNU Binutils are a collection of binary tools",

    authors = "GNU",
    licenses = "GPL",
    docs = "https://sourceware.org/binutils/wiki/HomePage",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"binutils", "gnu"},
    keywords = {"binutils", "gnu"},

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "ld", "as", "gold",
        "addr2line", "ar", "c++filt", "dlltool", "elfedit",
        "gprof", "nlmconv", "nm", "objcopy",
        "objdump", "ranlib", "readelf", "size", "strings", "strip",
        "windres", "windmc",
        -- "gprofng", TODO: fix cannot find -lrt: No such file or directory
    },

    xpm = {
        linux = {
            deps = { "make", "gcc", "glibc" },
            ["latest"] = { ref = "2.42" },
            ["2.42"] = {
                url = {
                    GLOBAL = __glic_url("2.42"),
                    CN = __glic_mirror_url("2.42"),
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

function install()

    local scode_binutils_dir = path.absolute("binutils-" .. pkginfo.version())
    local build_binutils_dir = "build-binutils"

    log.info("1.Creating build dir -" .. build_binutils_dir)
    os.tryrm(build_binutils_dir)
    os.mkdir(build_binutils_dir)

    log.info("2.Configuring binutils...")
    os.cd(build_binutils_dir)
    --local sysroot_dir = system.subos_sysrootdir()
    local binutils_prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_binutils_dir, "configure")
    system.exec(configure_file
        .. [[ --with-pkgversion="XPKG: xlings install fromsource:binutils"]]
        .. " --prefix=" .. binutils_prefix
        .. " --enable-plugins" -- enable gold plugin
        .. " --enable-new-dtags" -- use DT_RUNPATH to search shared libs
        .. " --disable-nls" -- disable native language support
        .. " --disable-gprofng" -- disable gprofng (TODO: fix build issue -ldl/-lrt)
        .. " --disable-werror"
        .. " --enable-gold --enable-ld=default" -- use gold as default linker
        --.. " --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu"
    )

    log.info("4.Building binutils...")
    system.exec("make -j24", { retry = 3 })

    log.info("5.Installing binutils...")
    -- TODO: use make install DESTDIR=$SYSROOT to avoid prefix hardcoding path in some files (libc.so)
    system.exec("make install")

    return true
end

function config()
    xvm.add("binutils")

    local binutils_root_binding = "binutils@" .. pkginfo.version()

    local binutils_bindir = path.join(pkginfo.install_dir(), "bin")

    for _, program in ipairs(package.programs) do
        xvm.add(program, {
            bindir = binutils_bindir,
            binding = binutils_root_binding,
        })
    end

    return true
end

function uninstall()
    xvm.remove("binutils")
    for _, program in ipairs(package.programs) do
        xvm.remove(program)
    end
    return true
end