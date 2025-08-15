-- https://mirrors.tuna.tsinghua.edu.cn/gnu/gcc/

package = {

    homepage = "https://musl.libc.org",

    -- base info
    name = "musl-gcc",
    description = "GCC - GNU Compiler Collection (Musl Libc)",

    authors = "Rich Felker, et al.",
    licenses = "GPL, MIT",
    repo = "https://git.musl-libc.org/cgit/musl",
    docs = "https://wiki.musl-libc.org",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"}, -- TODO: support multi-arch
    status = "stable", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "toolchain", "libc", "musl" },
    keywords = {"compiler", "gnu", "gcc", "toolchain", "c", "c++", "musl", "libc"},
    programs = {
        --"musl-gcc-static", "musl-g++-static",
        "musl-gcc", "musl-g++", "musl-c++", "musl-cpp",
        "musl-addr2line", "musl-ar", "musl-as", "musl-ld", "musl-nm",
        "musl-objcopy", "musl-objdump", "musl-ranlib", "musl-readelf",
        "musl-size", "musl-strings", "musl-strip",
    },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "musl-cross-make" },
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = {  },
            ["13.3.0"] = {  },
            ["12.4.0"] = {  },
            ["11.5.0"] = {  },
            ["10.3.0"] = {  },
            ["9.4.0"] = {  },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    system.exec(string.format("musl-cross-make %s %s %s",
        pkginfo.version(), "x86_64", install_dir
    ))
    return true
end

function config()
    local program_bindir = path.join(pkginfo.install_dir(), "bin")

    for _, program in ipairs(package.programs) do
        local program_fullname = "x86_64-linux-" .. program
        xvm.add(program_fullname, { bindir = program_bindir })
        xvm.add(program, {
            version = pkginfo.version(),
            bindir = program_bindir,
            alias = program_fullname,
        })
    end

-- runtime lib
    log.warn("add runtime libraries for musl-gcc-static...")
    local musl_lib_dir = path.join(
        pkginfo.install_dir(),
        "x86_64-linux-musl", "lib"
    )

    -- add musl's libc libc.so and libstdc++.so.6 , libgcc_s.so.1
    xvm.add("musl-libc", {
        version = "musl-gcc-" .. pkginfo.version(),
        filename = "libc.so",
        bindir = musl_lib_dir,
        type = "lib",
        alias = "libc.so",
    })

    xvm.add("libstdc++", {
        version = "musl-gcc-" .. pkginfo.version(),
        filename = "libstdc++.so.6",
        bindir = musl_lib_dir,
        type = "lib",
        alias = "libstdc++.so.6",
    })

    xvm.add("libgcc_s", {
        version = "musl-gcc-" .. pkginfo.version(),
        filename = "libgcc_s.so.1",
        bindir = musl_lib_dir,
        type = "lib",
        alias = "libgcc_s.so.1",
    })

    -- add ld.so (musl's ld.so wrapper)
    xvm.add("ld-musl", {
        version = "musl-gcc-" .. pkginfo.version(),
        filename = "ld-musl-x86_64.so.1",
        bindir = musl_lib_dir,
        type = "lib",
        alias = "libc.so",
    })

-- special commands
    xvm.add("musl-ldd", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so --list",
        envs = {
            -- ? alias = "libc.so --library-path musl_lib_dir --list",
            LD_LIBRARY_PATH = musl_lib_dir,
        }
    })

    xvm.add("musl-loader", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so",
        envs = {
            -- ? alias = "libc.so --library-path musl_lib_dir",
            LD_LIBRARY_PATH = musl_lib_dir,
        }
    })

    xvm.add("musl-gcc-static", {
        bindir = program_bindir,
        alias = "x86_64-linux-musl-gcc -static",
    })
    xvm.add("musl-g++-static", {
        bindir = program_bindir,
        alias = "x86_64-linux-musl-g++ -static",
    })
    return true
end

function uninstall()
    local install_dir = pkginfo.install_dir()
    for _, program in ipairs(package.programs) do
        xvm.remove(program)
        xvm.remove("x86_64-linux-" .. program)
    end
    -- runtime libraries
    xvm.remove("musl-libc", "musl-gcc-" .. pkginfo.version())
    xvm.remove("ld-musl", "musl-gcc-" .. pkginfo.version())
    xvm.remove("libstdc++", "musl-gcc-" .. pkginfo.version())
    xvm.remove("libgcc_s", "musl-gcc-" .. pkginfo.version())
    -- ld.so wrapper
    xvm.remove("musl-ldd", "musl-gcc-" .. pkginfo.version())
    xvm.remove("musl-loader", "musl-gcc-" .. pkginfo.version())
    xvm.remove("musl-gcc-static")
    xvm.remove("musl-g++-static")
    return true
end