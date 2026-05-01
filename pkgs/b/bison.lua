function __bison_url(version)
    return format("https://ftp.wayne.edu/gnu/bison/bison-%s.tar.xz", version)
end

function __bison_mirror_url(version)
    return format("https://ftpmirror.gnu.org/gnu/bison/bison-%s.tar.xz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                -- TODO: add fromsource:m4 (or xim:m4) when packaged.
                -- bison's configure script and runtime invoke `m4`. For now
                -- we rely on the host providing m4 (true on every reasonable
                -- builder + every distro CI runner).
            },
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
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "bison-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-bison")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing bison (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --disable-nls --disable-werror "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

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
