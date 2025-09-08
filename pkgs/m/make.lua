function __make_url(version) return format("https://ftp.wayne.edu/gnu/make/make-%s.tar.gz", version) end
function __make_mirror_url(version) return format("https://ftpmirror.gnu.org/gnu/make/make-%s.tar.gz", version) end

package = {
    homepage = "https://www.gnu.org/software/make",
    -- base info
    name = "make",
    description = "GNU Make Tool(Makefile)",

    authors = "GNU",
    licenses = "GPL",
    docs = "https://www.gnu.org/software/make/manual",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"make", "gnu", "makefile"},
    keywords = {"make", "gnu", "makefile"},

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "make", "gmake"
    },

    xpm = {
        linux = {
            deps = { "make", "musl-gcc" },
            ["latest"] = { ref = "4.3" },
            ["4.3"] = {
                url = {
                    GLOBAL = __make_url("4.3"),
                    CN = __make_mirror_url("4.3"),
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

    local scode_make_dir = path.absolute("make-" .. pkginfo.version())
    local build_make_dir = "build-make"

    log.info("1.Creating build dir -" .. build_make_dir)
    os.tryrm(build_make_dir)
    os.mkdir(build_make_dir)

    log.info("2.Configuring make...")
    os.cd(build_make_dir)
    local make_prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_make_dir, "configure")

    log.info("config musl-gcc-static to build make...")
    os.setenv("CC", "musl-gcc-static")
    os.setenv("CXX", "musl-g++-static")

    system.exec(configure_file
        .. " --prefix=" .. make_prefix
        .. " --disable-nls" -- disable native language support
        .. " --disable-werror"
    )

    log.info("4.Building make...")
    system.exec("make -j24", { retry = 3 })

    log.info("5.Installing make...")
    system.exec("make install")

    return true
end

function config()
    local make_bindir = path.join(pkginfo.install_dir(), "bin")
    local make_root_binding = "make@" .. pkginfo.version()

    xvm.add("make", { bindir = make_bindir })
    xvm.add("gmake", { alias = "make", binding = make_root_binding })

    return true
end

function uninstall()
    xvm.remove("make")
    xvm.remove("gmake")
    return true
end