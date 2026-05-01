function __glic_url(version) return format("https://ftp.gnu.org/gnu/binutils/binutils-%s.tar.gz", version) end
function __glic_mirror_url(version) return format("https://ftpmirror.gnu.org/gnu/binutils/binutils-%s.tar.xz", version) end

package = {
    spec = "1",

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
            deps = {
                "xim:make@4.3",
                "xim:gcc@15.1.0",
                "xim:glibc@2.39",
            },
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
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "binutils-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-binutils")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing binutils (autotools)...")
    -- pkgversion ascii doesn't include shell quotes; the literal
    -- `--with-pkgversion="XPKG: …"` previously here ended up storing the
    -- quotes inside the binary string. Switch to a quote-free form.
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --with-pkgversion=xlings-fromsource "
        .. "--prefix=%s --enable-plugins --enable-new-dtags --disable-nls "
        .. "--disable-gprofng --disable-werror --enable-gold --enable-ld=default "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ), { retry = 3 })

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