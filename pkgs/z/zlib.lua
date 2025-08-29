function qemu_url(version) return "https://download.qemu.org/qemu-" .. version .. ".tar.xz" end

package = {
    homepage = "www.zlib.net",

    -- base info
    name = "zlib",
    description = "...",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated

    -- TODO...
}

function install()
    os.cd("zlib-" .. pkginfo.version())
    system.exec("./configure --prefix=" .. pkginfo.install_dir())
    system.exec("make -j8", { retry = 3 })
    system.exec("make install")
    return true
end

function config()

end

function uninstall()

    return true
end