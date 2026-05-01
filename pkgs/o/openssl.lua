function __openssl_url(version)
    return format("https://www.openssl.org/source/openssl-%s.tar.gz", version)
end

package = {
    spec = "1",

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
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
                "xim:glibc@2.39",
            },
            ["latest"] = { ref = "3.1.5" },
            ["3.1.5"] = {
                url = __openssl_url("3.1.5"),
                sha256 = nil,
            },
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

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain Configure + make + install in single
    -- sh -c (os.cd doesn't propagate; openssl Configure does not support
    -- out-of-tree build, run from srcdir).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "openssl-" .. pkginfo.version())
    local prefix = pkginfo.install_dir()

    log.info("Configuring + building + installing openssl...")
    -- linux-x86_64:                explicit target (Configure auto-detect varies)
    -- enable-shared enable-legacy: ship .so libs + legacy ciphers
    -- no-asm:                      use C fallbacks for crypto routines.
    --                              openssl 3.1.5's perlasm output for AVX-512
    --                              (crypto/modes/aes-gcm-avx512.s) emits
    --                              `%SCALAR(...))` register names that the
    --                              binutils 2.42 assembler in our subos
    --                              rejects. C fallback is slower but stable.
    -- install_sw:                  skip docs install (saves several minutes)
    system.exec(string.format(
        "sh -c 'cd %s && ./Configure linux-x86_64 enable-shared enable-legacy no-asm --prefix=%s "
        .. "&& make -j8 && make install_sw'",
        scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib64")
    local includedir = path.join(pkginfo.install_dir(), "include")
    local sys_inc = _sys_usr_includedir()

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
    if not os.isdir(sys_inc) then os.mkdir(sys_inc) end
    if os.isdir(includedir) then
        -- shell cp -r: os.dirs / os.files glob is unreliable in 0.4.9 sandbox.
        -- openssl ships include/openssl/ subdir + ossl_typ.h-style flat files.
        system.exec(string.format(
            "sh -c 'cp -rf %s/* %s/'",
            includedir, sys_inc
        ))
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

    -- openssl headers live under include/openssl/. Sweep that subtree.
    local sys_inc = _sys_usr_includedir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/openssl 2>/dev/null || true'",
        sys_inc
    ))

    xvm.remove(xpkg_binding_tree)
    return true
end
