function _linux_download_url(version) return "https://www.python.org/ftp/python/" .. version .. "/Python-" .. version .. ".tar.xz" end

package = {
    homepage = "https://www.python.org",
    name = "python",
    description = "The Python programming language",
    maintainers = "Python Software Foundation",
    licenses = "PSF License | GPL compatible",
    repo = "https://github.com/python/cpython",
    docs = "https://docs.python.org/3",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"python", "plang", "interpreter"},
    keywords = {"python", "programming", "scripting", "language"},

    xpm = {
        linux = {
            deps = { "gcc@pmwrapper", "make" },
            ["latest"] = { ref = "3.13.1"},
            ["3.13.1"] = { url = _linux_download_url("3.13.1"), sha256 = nil },
            ["3.12.6"] = { url = _linux_download_url("3.12.6"), sha256 = nil },
            ["3.11.11"] = { url = _linux_download_url("3.11.11"), sha256 = nil },
            ["3.10.16"] = { url = _linux_download_url("3.10.16"), sha256 = nil },
            ["3.9.21"] = { url = _linux_download_url("3.9.21"), sha256 = nil },
            ["3.8.20"] = { url = _linux_download_url("3.8.20"), sha256 = nil },
        },
    },
}

import("common")
import("xim.base.utils")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")

function install()
    os.cd("Python-" .. pkginfo.version())
    --  build args - opt or todo?
        --enable-shared
        --with-computed-gotos 
        --with-lto
        --enable-ipv6
        --enable-loadable-sqlite-extensions
    -- todo: fix host and workspace issues
    system.exec("xvm workspace global --active false")
        os.exec([[./configure --enable-optimizations
            --prefix=]] .. pkginfo.install_dir()
        )
        os.exec("make -j$(nproc)")
        os.exec("make install")
        os.cd("..")
        os.tryrm("Python-" .. pkginfo.version())
    system.exec("xvm workspace global --active true")
    return true
end

function config()
    local xvm_python_template = "xvm add python %s --path %s/bin --alias python3"
    local xvm_pip_template = "xvm add pip %s --path %s/bin --alias pip3"
    os.exec(string.format(xvm_python_template, pkginfo.version(), pkginfo.install_dir()))
    os.exec(string.format(xvm_pip_template, "python-" .. pkginfo.version(), pkginfo.install_dir()))
    return true
end

function uninstall()
    os.exec("xvm remove python " .. pkginfo.version())
    os.exec("xvm remove pip " .. "python-" .. pkginfo.version())
    return true
end