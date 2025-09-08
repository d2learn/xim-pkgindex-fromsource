function __gcc_url(version) return format("https://ftpmirror.gnu.org/gnu/gcc/gcc-%s/gcc-%s.tar.xz", version, version) end

package = {
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
                "make", "gcc", "xz", "gzip", "bzip2",
                "linux-headers@5.11.1", "glibc@2.39", 
                "gcc-specs-config", "binutils@2.42",
                "make@4.3",
            },
            ["latest"] = { ref = "15.1.0" },
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
}

function install()
    local prerequisites_dir = path.absolute("comm-prerequisites")
    local sourcedir = path.absolute("gcc-" .. pkginfo.version())
    local builddir = path.absolute("gcc-build")

    log.info("0.clean build cache...")
    os.tryrm(prerequisites_dir)
    os.mkdir(prerequisites_dir)
    os.tryrm(builddir)

    log.info("1.download prerequisites...")
    os.cd(sourcedir)
    -- readfile - contrib/download_prerequisites
    local filecontent = io.readfile("contrib/download_prerequisites")
    filecontent = filecontent:replace("--no-verbose", " ", { plain = true })
    filecontent = filecontent:replace("ftp://gcc.gnu.org", "https://gcc.gnu.org", { plain = true })
    io.writefile("contrib/download_prerequisites", filecontent)
    system.exec("contrib/download_prerequisites --directory=" .. prerequisites_dir)

    --log.info("2.create linux sysroot...")
    --local sysroot_dir = path.join(builddir, "sysroot")

    os.mkdir(builddir)
    os.cd(builddir)
    --__create_sysroot(sysroot_dir)

    log.info("3.build config...")

    -- TODO: use workspace to build
    local old_glibc_info = xvm.info("glibc", "")
    local sysroot_dir = system.subos_sysrootdir()

-- config gcc (enable gcc-self run in xlings subos by gcc (xlings subos version))
--[[
    local linker_path = path.join(sysroot_dir, "lib/ld-linux-x86-64.so.2")
    local libdir = path.join(sysroot_dir, "lib")
    local gcc_config = string.format(
        -- CFLAGS="--sysroot=%s" CXXFLAGS="--sysroot=%s"  -- by --with-build-sysroot
         LDFLAGS="--dynamic-linker %s" , -- self
        --..  --with-extra-ldflags="--dynamic-linker %s --enable-new-dtags -rpath %s" , -- gcc target
        linker_path
]]

-- create workspace for build - todo

    xvm.use("glibc", "2.39")
    system.exec(string.format("%s"
        --.. gcc_config -- pass sysroot to gcc compile/link flags(for gcc)
        .. [[ --with-pkgversion="XPKG: xlings install fromsource:gcc"]]
        .. " --with-build-sysroot=" .. sysroot_dir -- glibc headers
        --.. " --with-native-system-header-dir=/include"
        .. " --with-sysroot=" .. sysroot_dir
        .. " --prefix=%s"
        .. " --enable-languages=c,c++"
        .. " --disable-multilib"
        .. " --disable-bootstrap"
        .. " --disable-werror"
        .. " --disable-lto" -- (--enable-lto) TODO: liblto_plugin.so -> libc.so.6 version mismatch
        .. " --enable-threads=posix"
        .. " --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu"
        .. " --disable-libsanitizer" -- sanitizer_platform_limits_posix.cc multiple definition of ‘enum fsconfig_command’
    , path.join(sourcedir, "configure"), pkginfo.install_dir()))


    log.info("4.build gcc...")
    system.exec("time make -j24", { retry = 3 })

    log.info("5.install gcc...")
    system.exec("make install")

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
