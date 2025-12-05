function __icu_url(version)
    local major_minor = version:match("^(%d+%.%d+)")
    return format("https://github.com/unicode-org/icu/releases/download/release-%s/icu4c-%s-src.tgz",
        version:gsub("%.", "-"), version:gsub("%.", "_"))
end

package = {
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
            deps = { "xpkg-helper", "gcc", "make" },
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

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local scode_icu_dir = path.absolute("icu")
    local build_icu_dir = "build-icu"

    log.info("1.Creating build dir -" .. build_icu_dir)
    os.tryrm(build_icu_dir)
    os.mkdir(build_icu_dir)

    log.info("2.Extracting ICU source...")
    -- Manually extract the ICU source archive
    local archive_name = "icu4c-" .. pkginfo.version():gsub("%.", "_") .. "-src.tgz"
    system.exec("tar -xzf " .. archive_name)

    log.info("3.Configuring ICU...")
    local icu_prefix = pkginfo.install_dir()

    -- Change to source directory for configuration
    os.cd(scode_icu_dir)
    -- Check if we need to enter the source subdirectory
    if os.isdir("source") then
        os.cd("source")
    end
    system.exec("./configure"
        .. [[ --with-pkgversion="XPKG: xlings install fromsource:icu"]]
        .. " --prefix=" .. icu_prefix
        .. " --disable-samples"
        .. " --disable-tests"
        .. " --enable-static=no"
        .. " --enable-shared=yes"
        .. " --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu"
    )

    log.info("4.Building ICU...")
    system.exec("make -j24")

    log.info("5.Installing ICU...")
    system.exec("make install")

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
    local icu_hdr_dir = path.join(pkginfo.install_dir(), "include")
    os.mkdir(sys_usr_includedir)

    -- Copy unicode headers
    local unicode_dir = path.join(icu_hdr_dir, "unicode")
    if os.isdir(unicode_dir) then
        os.cp(unicode_dir, sys_usr_includedir, { force = true })
    end

    -- Copy pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local icu_pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(icu_pc_dir) then
        for _, pc in ipairs(os.files(path.join(icu_pc_dir, "icu*.pc"))) do
            os.cp(pc, sys_pc_dir)
        end
    end

    xvm.add("icu", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("icu")

    for _, lib in ipairs(libs) do
        xvm.remove(lib, "icu-" .. pkginfo.version())
    end

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog, "icu-" .. pkginfo.version())
    end

    -- Remove header files
    os.tryrm(path.join(sys_usr_includedir, "unicode"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    if os.isdir(sys_pc_dir) then
        for _, pc in ipairs(os.files(path.join(sys_pc_dir, "icu*.pc"))) do
            os.tryrm(pc)
        end
    end

    xvm.remove("icu-binding-tree")

    return true
end
