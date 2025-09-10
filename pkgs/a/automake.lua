package = {
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
            deps = { "configure-project-installer" },
            ["latest"] = { ref = "1.16.5" },
            ["1.16.5"] = { },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local binding_tree = "automake-binding-tree"

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())

    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg
    )

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