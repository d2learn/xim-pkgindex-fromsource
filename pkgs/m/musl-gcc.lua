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
    namespace = "fromsource",
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
import("xim.libxpkg.log")

local runtime_libs = {
    "libc.so", -- "ld-musl-x86_64.so.1", -- musl-libc
    "libstdc++.so.6", "libgcc_s.so.1",
}

function install()
    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    system.exec(string.format("musl-cross-make %s" .. 
        " --target %s" ..
        " --output %s" ..
        " --with-dynamic-linker %s",
        pkginfo.version(), "x86_64", install_dir,
        -- xlings's global-workspace dir - ld.so
        "/home/xlings/.xlings_data/lib/ld-musl-x86_64.so.1"
    ))
    return true
end

function config()
    local program_bindir = path.join(pkginfo.install_dir(), "bin")

    -- binding tree - root node
    local binding_tree_root = "musl-gcc@" .. pkginfo.version()
    xvm.add("musl-gcc", {
        bindir = program_bindir,
        alias = "x86_64-linux-musl-gcc",
    })

    for _, program in ipairs(package.programs) do
        local program_fullname = "x86_64-linux-" .. program
        xvm.add(program_fullname, {
            bindir = program_bindir,
            binding = binding_tree_root,
        })
        if program ~= "musl-gcc" then
            xvm.add(program, {
                version = pkginfo.version(),
                bindir = program_bindir,
                alias = program_fullname,
                binding = binding_tree_root,
            })
        end
    end

-- runtime lib
    log.warn("add runtime libraries for musl-gcc-static...")
    local musl_lib_dir = path.join(
        pkginfo.install_dir(),
        "x86_64-linux-musl", "lib"
    )
    local runtime_lib_config = {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        type = "lib",
        binding = binding_tree_root,
    }

    for _, lib in ipairs(runtime_libs) do
        runtime_lib_config.filename = lib -- target file name
        runtime_lib_config.alias = lib -- source file name
        xvm.add(lib, runtime_lib_config)
    end

    -- add ld.so (musl's ld.so wrapper)
    runtime_lib_config.filename = "ld-musl-x86_64.so.1"
    runtime_lib_config.alias = "libc.so"
    xvm.add("ld-musl-x86_64.so.1", runtime_lib_config)

-- special commands
    xvm.add("musl-ldd", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so --list",
        envs = {
            -- ? alias = "libc.so --library-path musl_lib_dir --list",
            LD_LIBRARY_PATH = musl_lib_dir,
        },
        binding = binding_tree_root,
    })

    xvm.add("musl-loader", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so",
        envs = {
            -- ? alias = "libc.so --library-path musl_lib_dir",
            LD_LIBRARY_PATH = musl_lib_dir,
        },
        binding = binding_tree_root,
    })

    xvm.add("musl-gcc-static", {
        bindir = program_bindir,
        alias = "x86_64-linux-musl-gcc -static",
        binding = binding_tree_root,
    })
    xvm.add("musl-g++-static", {
        bindir = program_bindir,
        alias = "x86_64-linux-musl-g++ -static",
        binding = binding_tree_root,
    })
    return true
end

function uninstall()
    local install_dir = pkginfo.install_dir()
    local musl_gcc_version = "musl-gcc-" .. pkginfo.version()

    for _, program in ipairs(package.programs) do
        xvm.remove(program)
        xvm.remove("x86_64-linux-" .. program)
    end
    -- runtime libraries
    xvm.remove("ld-musl-x86_64.so.1", musl_gcc_version)
    for _, lib in ipairs(runtime_libs) do
        xvm.remove(lib, musl_gcc_version)
    end

    -- ld.so wrapper
    xvm.remove("musl-ldd", musl_gcc_version)
    xvm.remove("musl-loader", musl_gcc_version)
    xvm.remove("musl-gcc-static")
    xvm.remove("musl-g++-static")
    return true
end