function __automake_url(version)
    return format("https://ftp.gnu.org/gnu/automake/automake-%s.tar.gz", version)
end

package = {
    spec = "1",

    name = "automake",
    description = "A tool for automatically generating Makefile.in files",
    homepage = "https://www.gnu.org/software/automake/",
    repo = "https://git.savannah.gnu.org/git/automake.git",
    authors = "GNU Automake Team",
    licenses = "GPL-2.0-or-later",
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "build", "autotools", "makefiles" },
    keywords = { "automake", "aclocal", "makefile", "autoconf" },

    programs = { "automake", "aclocal" },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "1.16.5" },
            ["1.16.5"] = {
                url = __automake_url("1.16.5"),
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local binding_tree = "automake-binding-tree"

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (os.cd doesn't propagate to system.exec children).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "automake-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-automake")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing automake (autotools)...")
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding_root = binding_tree .. "@" .. pkginfo.version()

    xvm.add(binding_tree)

    log.info("Registering CLI programs...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = bindir,
            binding = binding_root,
        })
    end

    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    xvm.remove(binding_tree)
    return true
end
