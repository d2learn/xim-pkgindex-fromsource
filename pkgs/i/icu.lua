function __icu_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://github.com/unicode-org/icu/releases/download/release-%s/icu4c-%s-src.tgz",
        version:gsub("%.", "-"), version:gsub("%.", "_"))
end

package = {
    spec = "1",

    homepage = "https://icu.unicode.org",

    -- base info
    name = "icu",
    description = "International Components for Unicode - Unicode libraries and utilities",

    authors = "The ICU Project",
    licenses = "ICU License",
    repo = "https://github.com/unicode-org/icu",
    docs = "https://unicode-org.github.io/icu/",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",
    archs = { "x86_64" },
    status = "stable",
    categories = { "unicode", "internationalization", "text" },
    keywords = { "icu", "unicode", "i18n", "text", "localization" },

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "icu-config",
        "icuinfo",
        "icuexportdata",
        "uconv",
        "pkgdata",
        "genrb",
        "makeconv",
        "derb",
        "genbrk",
        "gencfu",
        "gencnval",
        "gendict",
        -- sbin tools
        "icupkg",
        "genccode",
        "gencmn",
        "gennorm2",
        "gensprep",
        "escapesrc",
    },

    xpm = {
        linux = {
            deps = {
                "xim:xpkg-helper@0.0.1",
                "xim:gcc@15.1.0",
                "xim:make@4.3",
            },
            ["latest"] = { ref = "77.1" },
            ["77.1"] = {
                url = {
                    GLOBAL = __icu_url("77.1"),
                    CN = __icu_url("77.1"),
                },
                sha256 = nil,
            },
            ["76.1"] = {
                url = {
                    GLOBAL = __icu_url("76.1"),
                    CN = __icu_url("76.1"),
                },
                sha256 = nil,
            },
            ["75.1"] = {
                url = {
                    GLOBAL = __icu_url("75.1"),
                    CN = __icu_url("75.1"),
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

local function icu_libs()
    local ver = pkginfo.version()
    local major = ver:match("^(%d+)") or ver
    local major_minor = ver:match("^(%d+%.%d+)") or major
    local bases = {
        "icuuc",
        "icui18n",
        "icudata",
        "icuio",
        "icutu",
        "icutest",
    }
    local out = {}
    for _, b in ipairs(bases) do
        local prefix = "lib" .. b .. ".so"
        table.insert(out, prefix)
        table.insert(out, prefix .. "." .. major)
        table.insert(out, prefix .. "." .. major_minor)
    end
    return out
end

local function _sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end
local function _sys_usr_libdir()
    return path.join(system.subos_sysrootdir(), "usr/lib")
end

function install()
    local runtime_dir = path.directory(pkginfo.install_file())
    local scode_dir = path.join(runtime_dir, "icu")
    local prefix = pkginfo.install_dir()

    log.info("Extracting + configuring + building + installing ICU...")
    -- ICU's tarball expands to icu/source/, not icu-<ver>/. The whole
    -- pipeline runs in one sh -c so cwd persists; tar runs in runtime_dir
    -- (where install_file lives), then we cd into the source subdir.
    local archive_name = "icu4c-" .. pkginfo.version():gsub("%.", "_") .. "-src.tgz"
    system.exec(string.format(
        "sh -c 'cd %s && tar -xzf %s && cd %s/source "
        .. "&& ./configure --with-pkgversion=xlings-fromsource --prefix=%s "
        .. "--disable-samples --disable-tests --enable-static=no --enable-shared=yes "
        .. "--build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu "
        .. "&& make -j8 && make install'",
        runtime_dir, archive_name, scode_dir, prefix
    ))

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "icu-binding-tree@" .. pkginfo.version()
    xvm.add("icu-binding-tree")

    log.info("Adding ICU libraries...")
    local config = {
        type = "lib",
        version = "icu-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib"),
        binding = version_tag,
    }

    for _, lib in ipairs(icu_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.info("Adding ICU programs...")
    local bin_root = path.join(pkginfo.install_dir(), "bin")
    local sbin_root = path.join(pkginfo.install_dir(), "sbin")
    local prog_config = {
        version = "icu-" .. pkginfo.version(),
        binding = version_tag,
    }

    for _, prog in ipairs(package.programs) do
        local candidate_bin = path.join(bin_root, prog)
        local candidate_sbin = path.join(sbin_root, prog)
        if os.isfile(candidate_sbin) then
            prog_config.bindir = sbin_root
        else
            prog_config.bindir = bin_root
        end
        prog_config.filename = prog
        prog_config.alias = prog
        xvm.add(prog, prog_config)
    end

    log.info("Adding header files to sysroot...")
    local sys_inc = _sys_usr_includedir()
    os.mkdir(sys_inc)
    local unicode_dir = path.join(pkginfo.install_dir(), "include", "unicode")
    if os.isdir(unicode_dir) then
        os.cp(unicode_dir, sys_inc, { force = true })
    end

    local sys_pc_dir = path.join(_sys_usr_libdir(), "pkgconfig")
    os.mkdir(sys_pc_dir)
    local icu_pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(icu_pc_dir) then
        system.exec(string.format(
            "sh -c 'cp -f %s/icu*.pc %s/ 2>/dev/null || true'",
            icu_pc_dir, sys_pc_dir
        ))
    end

    xvm.add("icu", { binding = version_tag })
    return true
end

function uninstall()
    xvm.remove("icu")
    for _, lib in ipairs(icu_libs()) do
        xvm.remove(lib, "icu-" .. pkginfo.version())
    end
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "icu-" .. pkginfo.version())
    end
    os.tryrm(path.join(_sys_usr_includedir(), "unicode"))
    system.exec(string.format(
        "sh -c 'rm -f %s/pkgconfig/icu*.pc'", _sys_usr_libdir()
    ))
    xvm.remove("icu-binding-tree")
    return true
end
