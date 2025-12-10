function __bison_url(version)
    return format("https://ftp.wayne.edu/gnu/bison/bison-%s.tar.xz", version)
end

function __bison_mirror_url(version)
    return format("https://ftpmirror.gnu.org/gnu/bison/bison-%s.tar.xz", version)
end

package = {
    homepage = "https://www.gnu.org/software/bison/",

    -- base info
    name = "bison",
    description = "Bison parser generator",

    authors = "GNU",
    licenses = "GPL",
    repo = "https://git.savannah.gnu.org/git/bison.git",
    docs = "https://www.gnu.org/software/bison/manual",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "build-tools", "parser", "gnu" },
    keywords = { "bison", "parser", "yacc", "gnu" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "bison", "yacc"
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "gcc", "make", "m4" },
            ["latest"] = { ref = "3.8.2" },
            ["3.8.2"] = {
                url = {
                    GLOBAL = __bison_url("3.8.2"),
                    CN = __bison_mirror_url("3.8.2"),
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
    local scode_dir = path.absolute("bison-" .. pkginfo.version())
    local build_dir = "build-bison"

    log.info("1.Creating build dir - " .. build_dir)
    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("2.Configuring bison...")
    os.cd(build_dir)
    local prefix = pkginfo.install_dir()
    local configure_file = path.join(scode_dir, "configure")

    system.exec(configure_file
        .. " --prefix=" .. prefix
        .. " --disable-nls"
        .. " --disable-werror"
    )

    log.info("3.Building bison...")
    system.exec("make -j24")

    log.info("4.Installing bison...")
    system.exec("make install")

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding bison to xvm...")
    
    local bindir = path.join(pkginfo.install_dir(), "bin")
    
    -- Register bison executable
    xvm.add("bison", {
        type = "bin",
        version = "bison-" .. pkginfo.version(),
        bindir = bindir,
    })
    
    -- Register yacc symlink/alias
    if os.exists(path.join(bindir, "yacc")) then
        xvm.add("yacc", {
            type = "bin",
            version = "bison-" .. pkginfo.version(),
            bindir = bindir,
        })
    end
    
    return true
end

function uninstall()
    xvm.remove("bison")
    xvm.remove("yacc")
    return true
end
