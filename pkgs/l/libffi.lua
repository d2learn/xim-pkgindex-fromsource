function __libffi_url(version)
    return format("https://github.com/libffi/libffi/releases/download/v%s/libffi-%s.tar.gz", version, version)
end

package = {
    spec = "1",

    homepage = "https://sourceware.org/libffi/",

    name = "libffi",
    description = "Portable Foreign Function Interface Library",

    authors = "Anthony Green, Red Hat, Inc and others.",
    licenses = "MIT",
    repo = "https://github.com/libffi/libffi",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"ffi", "system"},
    keywords = {"ffi", "lib", "ctypes", "interoperability"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "3.4.4" },
            ["3.4.4"] = {
                url = __libffi_url("3.4.4"),
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

local libs = {
    "libffi.so",
    "libffi.so.8",
    "libffi.a",
}

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    -- Sandbox template (PR #49 bzip2): derive paths from pkginfo.install_file()
    -- since path.absolute is nil; chain configure + make + install in single
    -- sh -c (os.cd doesn't propagate to system.exec children).
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "libffi-" .. pkginfo.version())
    local build_dir = path.join(runtime_dir, "build-libffi")
    local prefix = pkginfo.install_dir()

    os.tryrm(build_dir)
    os.mkdir(build_dir)

    log.info("Configuring + building + installing libffi (autotools)...")
    -- --disable-exec-static-tramp: works around libffi 3.4.4 build break on
    -- gcc 14+ where src/tramp.c calls open_temp_exec_file (defined later in
    -- src/closures.c) without a forward decl, hitting -Werror=implicit-function-declaration.
    system.exec(string.format(
        "sh -c 'cd %s && %s/configure --prefix=%s --disable-static --enable-shared "
        .. "--disable-exec-static-tramp "
        .. "&& make -j8 && make install'",
        build_dir, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "libffi-binding-tree@" .. pkginfo.version()
    xvm.add("libffi-binding-tree")

    log.warn("add libs...")
    -- libffi installs to lib/ on some distros, lib64/ on others; pick whichever is present
    local libdir = path.join(pkginfo.install_dir(), "lib64")
    if not os.isdir(libdir) then
        libdir = path.join(pkginfo.install_dir(), "lib")
    end

    local config = {
        type = "lib",
        version = "libffi-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    if not os.isdir(sys_inc) then os.mkdir(sys_inc) end

    -- shell cp glob: os.cp(path/*, dst) silently no-ops in 0.4.9 sandbox
    system.exec(string.format(
        "sh -c 'cp -f %s/include/*.h %s/'",
        pkginfo.install_dir(), sys_inc
    ))

    xvm.add("libffi", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("libffi")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "libffi-" .. pkginfo.version())
    end

    local sys_inc = _sys_usr_includedir()
    os.tryrm(path.join(sys_inc, "ffi.h"))
    os.tryrm(path.join(sys_inc, "ffitarget.h"))

    xvm.remove("libffi-binding-tree")

    return true
end
