package = {
    -- base info
    name = "glibc",
    description = "XIM Package File Template",

    authors = "sunrisepeak",
    license = "Apache-2.0",
    repo = "https://github.com/d2learn/xim-pkgindex",

    -- xim pkg info
    type = "package",
    namespace = "fromsource",

    xpm = {
        linux = {
            ["0.0.0"] = { },
        },
    },
}

function installed()
    return os.iorun("xvm list glibc")
end

function install()
    print("install glibc...")

    -- your install implementation
    -- ...

    return true
end

function config()
    -- your config implementation
    -- ...

    -- config xvm
    return true
end

function uninstall()
    os.exec("xvm remove glibc " .. pkginfo.version)

    -- your uninstall implementation
    -- ...

    return true
end