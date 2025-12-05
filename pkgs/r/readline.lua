package = {
    homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html",

    name = "readline",
    description = "GNU Readline Library for Command-line Editing",

    authors = "Chet Ramey",
    licenses = "GPL",
    repo = "https://ftp.gnu.org/gnu/readline/",

    type = "package",
    namespace = "fromsource",
    archs = {"x86_64"},
    status = "stable",
    categories = {"cli", "terminal"},
    keywords = {"readline", "lib", "cli", "shell"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xpkg-helper", "gcc", "make@4.3",
                "configure-project-installer",
                "ncurses@6.4", -- for shared termcap library
                "gcc@11", -- readline 8.2 requires at least gcc 11, but < 15
            },
            ["latest"] = { ref = "8.2" },
            ["8.2"] = {},
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.utils")

local function readline_libs()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local out = {}
    
    -- Scan for all libreadline*.so* and libhistory*.so* files
    for _, file in ipairs(os.files(path.join(libdir, "libreadline*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    for _, file in ipairs(os.files(path.join(libdir, "libhistory*.so*"))) do
        local name = path.filename(file)
        table.insert(out, name)
    end
    
    -- Add static libraries
    table.insert(out, "libreadline.a")
    table.insert(out, "libhistory.a")
    
    return out
end

local sys_usr_includedir = path.join(system.subos_sysrootdir(), "usr/include")

function install()
    local xpkg = package.name .. "@" .. pkginfo.version()
    local src_dir = path.absolute("readline-" .. pkginfo.version())

    os.tryrm(pkginfo.install_dir())
    os.tryrm(src_dir)

    pkgmanager.install("scode:" .. xpkg)
    system.exec(string.format("xpkg-helper scode:%s --export-path %s", xpkg, src_dir))

    __patch_for_readline(src_dir)

    -- TODO: add rpath for shared libraries?
    -- https://stackoverflow.com/questions/46881581/libreadline-so-7-undefined-symbol-up
    os.setenv("LDFLAGS", "-Wl,-rpath,/home/xlings/.xlings_data/subos/linux/lib")
    
    -- Use ncurses instead of termcap (modern ncurses removed termcap compat)
    system.exec("configure-project-installer " .. pkginfo.install_dir()
        .. " --project-dir " .. src_dir
        -- " --args " .. [[ "--enable-shared --with-curses" ]]
        -- undefined-symbol-up - xmake
        .. " --args " .. [[ "--enable-shared --with-shared-termcap-library" ]]
    )

    return os.isdir(pkginfo.install_dir())
end

function config()
    local version_tag = "readline-binding-tree@" .. pkginfo.version()
    xvm.add("readline-binding-tree")

    log.warn("add libs...")
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local config = {
        type = "lib",
        version = "readline-" .. pkginfo.version(),
        bindir = libdir,
        binding = version_tag,
    }

    for _, lib in ipairs(readline_libs()) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.warn("add header files to sysroot...")
    local hdr_dir = path.join(pkginfo.install_dir(), "include", "readline")
    local sys_readline_includedir = path.join(sys_usr_includedir, "readline")
    os.mkdir(sys_usr_includedir)
    os.cp(hdr_dir, sys_readline_includedir, { force = true })

    -- Copy pkgconfig files
    log.warn("add pkgconfig files to sysroot...")
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sys_pc_dir)
    local pc_dir = path.join(pkginfo.install_dir(), "lib/pkgconfig")
    if os.isdir(pc_dir) then
        for _, pc in ipairs(os.files(path.join(pc_dir, "*.pc"))) do
            os.cp(pc, sys_pc_dir)
        end
    end

    xvm.add("readline", { binding = version_tag })

    return true
end

function uninstall()
    xvm.remove("readline")

    for _, lib in ipairs(readline_libs()) do
        xvm.remove(lib, "readline-" .. pkginfo.version())
    end

    os.tryrm(path.join(sys_usr_includedir, "readline"))

    -- Remove pkgconfig files
    local sys_pc_dir = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "readline*.pc"))) do
        os.tryrm(pc)
    end
    for _, pc in ipairs(os.files(path.join(sys_pc_dir, "history*.pc"))) do
        os.tryrm(pc)
    end

    xvm.remove("readline-binding-tree")

    return true
end

-- private
-- fix build python crash coredump issue
function __patch_for_readline(src_dir)
    local patch_url_template = "https://ftpmirror.gnu.org/gnu/readline/readline-8.2-patches/readline82-" -- XX.patch
    os.cd(src_dir)
    -- from 001 -> 013
    for i = 1, 13 do
        local patch_num = string.format("%03d", i)
        local patch_url = patch_url_template .. patch_num
        local patch_file = "readline82-" .. patch_num -- .. ".patch"
        log.warn("[%02d/13] - download patch: %s", i, patch_url)
        utils.try_download_and_check(patch_url, src_dir)
        --os.trymv("readline82-" .. patch_num, patch_file)
        log.warn("apply patch: " .. patch_file)
        system.exec("patch -p0 -i " .. patch_file)
    end
end