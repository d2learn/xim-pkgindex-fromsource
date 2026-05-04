## Cursor Cloud specific instructions

### Project overview

This is `xim-pkgindex-fromsource`, a package index repository for the [xlings](https://github.com/openxlings/xlings) ecosystem's `xim` package manager. It defines how to build ~45 system-level software packages **from source code** on Linux (x86_64). The repository contains only Lua package definition files — there are no compiled applications or running services.

### Development environment

- **Lua 5.4** is needed for `luac -p` syntax validation of `.lua` package files.
- **Python 3 + pytest** is needed to run the test suite.
- There is no build step or dev server to run — the "application" is the collection of Lua package definitions consumed by the external `xim` tool.

### Running tests

```bash
# L0 + L2 (fast, no external deps): static analysis + isolation compliance
pytest tests/ -m "static or isolation" --tb=short -q

# L0 only: field validation, Lua syntax, dep versioning
pytest tests/ -m static

# L2 only: subos isolation compliance
pytest tests/ -m isolation

# L1 (requires xlings installed): index registration
pytest tests/ -m index

# Single package test
pytest tests/g/test_gcc.py -m "static or isolation" -v
```

See `docs/test/usage.md` for the full test guide.

### Linting

- Lua syntax check: `for f in pkgs/*/*.lua; do luac -p "$f"; done`
- LD_LIBRARY_PATH policy: `bash .github/scripts/check-no-direct-ld-libpath.sh`
- Combined L0+L2 pytest covers all linting needs.

### Key conventions

- Every package file must have `spec = "1"` (V1 spec).
- All dependencies must use explicit versions: `"pkgname@version"` (enforced by `assert_deps_versioned`).
- Do not use `LD_LIBRARY_PATH` directly unless the package is in the allowlist (see `.github/scripts/check-no-direct-ld-libpath.sh`).
- Use `xvm.add()` API, not `os.exec("xvm add ...")`.
- Use `xim.libxpkg.*` imports, not legacy `import("common")` or `import("platform")`.
- Test file naming: `pkgs/x/foo-bar.lua` → `tests/x/test_foo_bar.py`.
