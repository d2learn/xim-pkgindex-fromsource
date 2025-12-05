function __meson_url(version)
    return format("https://github.com/mesonbuild/meson/archive/refs/tags/%s.tar.gz",
        version)
end

package = {
    homepage = "https://mesonbuild.com",

    -- base info
    name = "meson",
    description = "The Meson Build System",

    authors = "The Meson Team",
    licenses = "Apache-2.0",
    repo = "https://github.com/mesonbuild/meson",
    docs = "https://mesonbuild.com",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "build", "system" },
    keywords = { "meson", "build", "system" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "meson",
    },

    xpm = {
        linux = {
            deps = { "xpkg-helper", "python" },
            ["latest"] = { ref = "1.9.1" },
            ["1.9.1"] = {
                url = {
                    GLOBAL = __meson_url("1.9.1"),
                    CN = __meson_url("1.9.1"),
                },
                sha256 = nil,
            },
            ["1.8.0"] = {
                url = {
                    GLOBAL = __meson_url("1.8.0"),
                    CN = __meson_url("1.8.0"),
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

function install()
    local scode_meson_dir = path.absolute("meson-" .. pkginfo.version())
    local meson_prefix = pkginfo.install_dir()

    log.info("Installing meson...")

    os.tryrm(pkginfo.install_dir())
    -- Copy meson files to install directory
    os.cp(scode_meson_dir, meson_prefix, { force = true })

    return os.isdir(pkginfo.install_dir())
end

function config()
    log.info("Adding meson program...")
    local bin_config = { alias = "meson.py" }
    xvm.add("meson", bin_config)
    return true
end

function uninstall()
    xvm.remove("meson")
    return true
end
