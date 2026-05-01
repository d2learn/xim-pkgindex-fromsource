function __gcc_url(version) return format("https://ftpmirror.gnu.org/gnu/gcc/gcc-%s/gcc-%s.tar.xz", version, version) end

package = {
    spec = "1",

    -- base info
    name = "gcc",
    description = "GCC, the GNU Compiler Collection",

    authors = "GNU",
    licenses = "GPL",
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "language"},
    keywords = {"compiler", "gnu", "gcc", "language", "c", "c++"},

    programs = {
        "gcc", "g++", "c++", "cpp",
        "gcc-ar", "gcc-nm", "gcc-ranlib",
        "gcov", "gcov-dump", "gcov-tool",
        "x86_64-linux-gnu-gcc", "x86_64-linux-gnu-g++", "x86_64-linux-gnu-c++",
    },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:make@4.3",
                "xim:gcc@15.1.0",                   -- bootstrap gcc (use prebuilt to compile new gcc)
                "xim:linux-headers@5.11.1",
                "xim:glibc@2.39",
                "xim:binutils@2.42",
                "xim:gcc-specs-config@0.0.1",
                "fromsource:bzip2@1.0.8",
                "fromsource:xz-utils@5.4.5",        -- fix: was 'xz' (wrong package name)
                -- gzip dropped: no gzip xpkg in any registered indexrepo;
                -- system tar handles .gz extraction. TODO: package gzip later.
            },
            ["latest"] = { ref = "16.1.0" },
            ["16.1.0"] = {
                url = __gcc_url("16.1.0"),
                sha256 = "50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79",
            },
            ["15.1.0"] = { url = __gcc_url("15.1.0") },
            ["14.2.0"] = { url = __gcc_url("14.2.0") },
            ["13.3.0"] = { url = __gcc_url("13.3.0") },
            ["12.4.0"] = { url = __gcc_url("12.4.0") },
            ["11.5.0"] = { url = __gcc_url("11.5.0") },
            ["9.4.0"] = { url = __gcc_url("9.4.0") },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local gcc_tool = {
    ["gcc-ar"] = true, ["gcc-nm"] = true, ["gcc-ranlib"] = true,
    ["gcov"] = true, ["gcov-dump"] = true, ["gcov-tool"] = true,
}

local gcc_lib = {
    -- not include glibc
    "libgcc_s.so", "libgcc_s.so.1",
    "libstdc++.so", "libstdc++.so.6",
    "libatomic.so", "libatomic.so.1",
    -- asan
    "libasan.so", "libasan.so.8",
}

function install()
    -- Sandbox template (PR #49 bzip2):
    --   * `path.absolute` is nil → derive from `pkginfo.install_file()`
    --     (the absolute tarball path xlings already gives us in runtimedir).
    --   * `os.cd` doesn't propagate to system.exec children → chain
    --     download_prerequisites + configure + make + make install in
    --     a single sh -c so cwd persists.
    --   * `os.cpuinfo` is nil → fixed `-j8`.
    local runtime_dir = path.directory(pkginfo.install_file())
    local prerequisites_dir = path.join(runtime_dir, "comm-prerequisites")
    local sourcedir = path.join(runtime_dir, "gcc-" .. pkginfo.version())
    local builddir = path.join(runtime_dir, "gcc-build")
    local prefix = pkginfo.install_dir()
    local sysroot_dir = system.subos_sysrootdir()

    log.info("0.clean build cache...")
    os.tryrm(prerequisites_dir)
    os.mkdir(prerequisites_dir)
    os.tryrm(builddir)
    os.mkdir(builddir)

    log.info("1.patching contrib/download_prerequisites (--no-verbose, ftp→https)...")
    -- This part runs inside the lua sandbox (no system.exec) so it's fine.
    local prereq_script = path.join(sourcedir, "contrib/download_prerequisites")
    local filecontent = io.readfile(prereq_script)
    filecontent = filecontent:replace("--no-verbose", " ", { plain = true })
    filecontent = filecontent:replace("ftp://gcc.gnu.org", "https://gcc.gnu.org", { plain = true })
    io.writefile(prereq_script, filecontent)

    -- TODO: use workspace to build
    local old_glibc_info = xvm.info("glibc", "")
    xvm.use("glibc", "2.39")

    log.info("2.download prerequisites + configure + build + install gcc...")
    -- Single sh -c: download_prerequisites runs from sourcedir; configure
    -- runs from builddir. `time make -j8` may exceed default xlings retry
    -- timeout; retry=3 left in place so transient mirror flakes don't kill
    -- a 30-minute build.
    system.exec(string.format(
        "sh -c 'cd %s && contrib/download_prerequisites --directory=%s "
        .. "&& cd %s && %s/configure "
        .. "--with-pkgversion=xlings-fromsource "
        .. "--with-build-sysroot=%s --with-sysroot=%s --prefix=%s "
        .. "--enable-languages=c,c++ --disable-multilib --disable-bootstrap "
        .. "--disable-werror --disable-lto --enable-threads=posix "
        .. "--build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu "
        .. "--enable-libsanitizer "
        .. "&& time make -j8 && make install'",
        sourcedir, prerequisites_dir,
        builddir, sourcedir,
        sysroot_dir, sysroot_dir, prefix
    ), { retry = 3 })

    xvm.use("glibc", old_glibc_info["Version"])
    return true
end

function config()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local ld_lib_path = string.format(path.join(pkginfo.install_dir(), "lib64"))

    xvm.add("xim-gnu-gcc") -- root

    local config = {
        bindir = gcc_bindir,
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
        envs = {
            --["LD_LIBRARY_PATH"] = ld_lib_path,
            --["LD_RUN_PATH"] = ld_lib_path,
        }
    }

    log.warn("add gcc bin...")
    for _, prog in ipairs(package.programs) do
        if gcc_tool[prog] then
            config.version = "gcc-" .. pkginfo.version()
            xvm.add(prog, config)
        else
            config.version = pkginfo.version()
            xvm.add(prog, config)
        end
    end

-- lib
    log.warn("add gcc libs...")
    local lib_config = {
        type = "lib",
        version = "gcc-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib64"),
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
    }

    for _, lib in ipairs(gcc_lib) do
        lib_config.filename = lib -- target file name
        lib_config.alias = lib -- source file name
        xvm.add(lib, lib_config)
    end


    log.warn("gcc spec config...")
    local sysrootdir = system.subos_sysrootdir()
    local linker_path = path.join(sysrootdir, "lib/ld-linux-x86-64.so.2")
    local libdir = path.join(sysrootdir, "lib")
    local gcc_bin = path.join(pkginfo.install_dir(), "bin/gcc")

    system.exec("gcc-specs-config "
        .. gcc_bin
        .. " --dynamic-linker " .. linker_path
        .. " --rpath " .. libdir
        .. " --linker-type gnu"
    )

    xvm.add("cc", {
        alias = "gcc",
        version = pkginfo.version(),
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
    })

    return true
end

function uninstall()

    local gcc_version = "gcc-" .. pkginfo.version()

    for _, prog in ipairs(package.programs) do
        if gcc_tool[prog] then
            xvm.remove(prog, gcc_version)
        else
            xvm.remove(prog)
        end
    end
    for _, lib in ipairs(gcc_lib) do
        xvm.remove(lib, gcc_version)
    end
    xvm.remove("xim-gnu-gcc")
    xvm.remove("cc")
    return true
end

--[[

Libraries have been installed in:
   /home/xlings/.xlings_data/xim/xpkgs/fromsource-x-gcc/9.4.0/lib/../lib64

If you ever happen to want to link against installed libraries
in a given directory, LIBDIR, you must either use libtool, and
specify the full pathname of the library, or use the `-LLIBDIR'
flag during linking and do at least one of the following:
   - add LIBDIR to the `LD_LIBRARY_PATH' environment variable
     during execution
   - add LIBDIR to the `LD_RUN_PATH' environment variable
     during linking
   - use the `-Wl,-rpath -Wl,LIBDIR' linker flag
   - have your system administrator add LIBDIR to `/etc/ld.so.conf'

]]
