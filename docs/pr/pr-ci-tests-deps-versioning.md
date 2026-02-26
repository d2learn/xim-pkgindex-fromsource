# PR 修改报告: CI、测试框架与依赖版本化

## 概述

本 PR 为 xim-pkgindex-fromsource 仓库添加了完整的 CI 流水线、自动化测试框架，并为所有 45 个从源码构建的包添加了明确的依赖版本号，确保符合 xlings 的多版本共存及 subos 环境隔离要求。

## 修改内容

### 1. 包定义修改 (45 个文件)

#### 1.1 添加 spec 字段

所有包文件添加了 `spec = "1"` 字段，符合 V1 规范:

```lua
package = {
    spec = "1",  -- 新增
    name = "zlib",
    ...
}
```

#### 1.2 依赖版本化

所有依赖项添加了明确版本号 (`pkgname@version`):

| 修改前 | 修改后 |
|--------|--------|
| `"gcc"` | `"gcc@15.1.0"` |
| `"make"` | `"make@4.3"` |
| `"zlib"` | `"zlib@1.3.1"` |
| `"xpkg-helper"` | `"xpkg-helper@0.0.1"` |
| `"configure-project-installer"` | `"configure-project-installer@0.0.1"` |
| `"ninja"` | `"ninja@1.12.1"` |
| `"gcc@11"` | `"gcc@11.5.0"` |
| `"libxml2@latest"` | `"libxml2@2.15.0"` |

完整版本映射:

| 依赖 | 版本 | 来源 |
|------|------|------|
| xpkg-helper | 0.0.1 | 主索引仓库 (script) |
| configure-project-installer | 0.0.1 | 主索引仓库 (script) |
| gcc-specs-config | 0.0.1 | 主索引仓库 (script) |
| musl-cross-make | 0.0.1 | 主索引仓库 (script) |
| ninja | 1.12.1 | 主索引仓库 |
| gcc | 15.1.0 | fromsource |
| make | 4.3 | fromsource |
| musl-gcc | 15.1.0 | fromsource |
| python | 3.13.1 | fromsource |
| meson | 1.9.1 | fromsource |
| zlib | 1.3.1 | fromsource |
| glibc | 2.39 | fromsource |
| binutils | 2.42 | fromsource |
| linux-headers | 5.11.1 | fromsource |
| ncurses | 6.4 | fromsource |
| readline | 8.2 | fromsource |
| openssl | 3.1.5 | fromsource |
| xz-utils | 5.4.5 | fromsource |
| libffi | 3.4.4 | fromsource |
| bzip2 | 1.0.8 | fromsource |
| util-linux | 2.39.3 | fromsource |
| freetype | 2.13.2 | fromsource |
| fontconfig | 2.14.2 | fromsource |
| expat | 2.6.2 | fromsource |
| libpng | 1.6.43 | fromsource |
| pixman | 0.42.2 | fromsource |
| harfbuzz | 8.3.0 | fromsource |
| cairo | 1.18.0 | fromsource |
| libxml2 | 2.15.0 | fromsource |
| pcre2 | 10.42 | fromsource |
| xorgproto | 2024.1 | fromsource |
| xorg-macros | 1.20.1 | fromsource |
| xtrans | 1.5.2 | fromsource |
| xcb-proto | 1.17.0 | fromsource |
| libxcb | 1.17.0 | fromsource |
| libxau | 1.0.11 | fromsource |
| libxdmcp | 1.1.5 | fromsource |
| libx11 | 1.8.10 | fromsource |
| bison | 3.8.2 | fromsource |
| glib | 2.82.2 | fromsource |
| icu | 77.1 | fromsource |
| m4 | 1.4.19 | 系统工具 |
| gzip | 1.13 | 系统工具 |
| xz | 5.4.5 | fromsource |

#### 1.3 其他修复

- `gcc.lua`: 移除重复的 `"make@4.3"` 依赖项
- `readline.lua`: `gcc@11` → `gcc@11.5.0` (明确版本号)
- `pango.lua`: `gcc@11` → `gcc@11.5.0` (明确版本号)
- `libxkbcommon.lua`: `libxml2@latest` → `libxml2@2.15.0` (消除不确定性)

### 2. 测试框架 (新增)

#### 2.1 测试基础设施

| 文件 | 说明 |
|------|------|
| `tests/pytest.ini` | pytest 配置，定义测试层级标记 |
| `tests/conftest.py` | 全局 fixtures 和标记注册 |
| `tests/lib/xpkg_parser.py` | Lua 包文件解析器（正则提取，不依赖 Lua 运行时） |
| `tests/lib/assertions.py` | 通用断言函数（L0-L4 全覆盖） |
| `tests/lib/xvm_client.py` | xvm 操作封装 |
| `tests/lib/xlings_client.py` | xlings install/remove 封装 |
| `tests/lib/platform_utils.py` | 平台检测与路径工具 |

#### 2.2 测试文件 (45 个)

每个 `pkgs/<x>/<name>.lua` 对应 `tests/<x>/test_<name>.py`，覆盖:

- **L0 静态** (7 项): required_fields, valid_spec, valid_type, no_typos, lua_syntax, deps_versioned, lifecycle_hooks
- **L2 隔离** (7 项): no_exec_xvm, no_bashrc, no_path_modification, no_direct_ld_libpath, no_deprecated_libpath, new_api, no_direct_pkg_manager
- **L1 索引** (1 项): xim_add
- **L3 生命周期** (1 项): install
- **L4 功能验证** (1+ 项): version/xvm_registered

#### 2.3 测试结果

```
628 passed, 2 xfailed

L0 静态分析: 315 passed ✅
L2 隔离合规: 313 passed, 2 xfailed ✅
```

已知问题 (xfail):
| 包 | 问题 | 说明 |
|----|------|------|
| python | `import("common")` 旧 API | 待迁移到 `xim.libxpkg.*` |
| qemu | 直接调用 `pacman -S` | 待迁移到 deps 声明 |

### 3. CI 配置 (新增)

#### 3.1 Workflows

| 文件 | 触发 | 内容 |
|------|------|------|
| `ci-xpkg-test.yml` | push/PR (pkgs/tests 变更) | L0 静态 + L2 隔离 → L1 索引注册 |
| `ci-test.yml` | push (pkgs 变更) | 变更文件 xim --add-xpkg 验证 + libpath lint |

#### 3.2 策略脚本

| 文件 | 说明 |
|------|------|
| `.github/scripts/check-no-direct-ld-libpath.sh` | LD_LIBRARY_PATH 使用策略检查 |

白名单:
- `pkgs/m/musl-gcc.lua` — musl 动态链接器包装器
- `pkgs/p/python.lua` — subos 运行时 lib 路径
- `pkgs/l/libxkbcommon.lua` — 构建时依赖解析

### 4. 文档 (新增)

| 文件 | 说明 |
|------|------|
| `docs/test/design.md` | 测试框架设计文档 |
| `docs/test/usage.md` | 测试使用指南 |
| `docs/test/ci.md` | CI workflow 说明 |
| `docs/pr/pr-ci-tests-deps-versioning.md` | 本修改报告 |

## 多版本共存与 subos 隔离合规

### 测试覆盖

以下检查确保 fromsource 包符合 xlings 多版本共存和 subos 环境隔离要求:

1. **xvm API 使用** (`assert_no_exec_xvm`): 确保使用 `xvm.add()` API 而非 `os.exec("xvm add ...")`
2. **shell 配置隔离** (`assert_no_bashrc_modification`): 不修改 `.bashrc` / shell profile
3. **PATH 隔离** (`assert_no_direct_path_modification`): 不直接操作 `PATH`，通过 xvm shim 路由
4. **LD_LIBRARY_PATH 策略** (`assert_no_direct_ld_libpath`): 避免直接设置，使用 elfpatch RPATH
5. **新 API 使用** (`assert_uses_new_api`): 使用 `xim.libxpkg.*` 而非旧版 API
6. **包管理器隔离** (`assert_no_direct_pkg_manager`): 不直接调用 apt/pacman/brew
7. **版本固化** (`assert_deps_versioned`): 所有依赖有明确版本号，支持确定性构建

### xvm 多版本视图

所有 fromsource 包通过 `xvm.add()` 注册到 xvm，支持:
- 同一工具多版本共存（如 gcc 9.4.0 和 15.1.0）
- 通过 `xvm use` 切换版本
- subos 中通过 shim 透明路由
- binding 机制关联主程序和附属程序/库

## 文件变更汇总

```
修改: 45 个包定义文件 (pkgs/*/*.lua)
新增: 54 个文件
  - 45 个测试文件 (tests/*/*.py)
  - 5 个测试框架文件 (tests/lib/*.py)
  - 2 个测试配置文件 (tests/conftest.py, tests/pytest.ini)
  - 1 个测试 .gitignore
  - 2 个 CI workflow 文件 (.github/workflows/*.yml)
  - 1 个策略检查脚本 (.github/scripts/*.sh)
  - 3 个文档文件 (docs/test/*.md)
  - 1 个 PR 报告 (docs/pr/*.md)
```
