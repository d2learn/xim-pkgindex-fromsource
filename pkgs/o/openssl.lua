package = {
    homepage = "https://www.openssl.org",
    name = "openssl",
    description = "TLS/SSL and cryptography toolkit",
    authors = "The OpenSSL Project",
    licenses = "Apache-2.0",
    repo = "https://github.com/openssl/openssl",
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "crypto", "tls", "ssl", "library" },
    keywords = { "openssl", "libssl", "libcrypto", "tls", "ssl", "https" },

    programs = {
        "openssl", "c_rehash"
    },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "configure-project-installer", "glibc" },
            ["latest"] = { ref = "3.1.5" },
            ["3.1.5"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local libs = {
    "libcrypto.so", "libcrypto.so.3", "libcrypto.a",
    "libssl.so",    "libssl.so.3",    "libssl.a"
}

local xpkg_binding_tree = package.name .. "-binding-tree"
local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())

    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --xpkg-scode " .. xpkg
        .. " --args " .. [[ "enable-shared enable-legacy" ]]
    )

    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib64")
    local includedir = path.join(pkginfo.install_dir(), "include")

    log.info("Registering CLI programs...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = bindir,
            binding = binding_tree_version_tag,
        })
    end

    log.info("Registering libraries...")
    local config = {
        type = "lib",
        version = package.name .. "-" .. pkginfo.version(),
        bindir = libdir,
        binding = binding_tree_version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Installing headers to sysroot...")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            local name = path.filename(subdir)
            os.tryrm(path.join(sys_usr_includedir, name))
            os.cp(subdir, path.join(sys_usr_includedir, name), { force = true })
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.cp(file, sys_usr_includedir)
        end
    end

    xvm.add(package.name, { binding = binding_tree_version_tag })
    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end

    for _, lib in ipairs(libs) do
        xvm.remove(lib, package.name .. "-" .. pkginfo.version())
    end

    local includedir = path.join(pkginfo.install_dir(), "include")
    if os.isdir(includedir) then
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(subdir)))
        end

        for _, file in ipairs(os.files(path.join(includedir, "*.h"))) do
            os.tryrm(path.join(sys_usr_includedir, path.filename(file)))
        end
    end

    xvm.remove(xpkg_binding_tree)
    return true
end