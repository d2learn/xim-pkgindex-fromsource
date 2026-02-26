# xpkg fromsource 包测试框架设计文档

> 相关文档: [使用指南](usage.md) | [CI 说明](ci.md)

## 1. 概述

### 1.1 目标

为 xim-pkgindex-fromsource 仓库中的所有 xpkg 从源码构建包提供自动化测试，覆盖：
- **静态分析**: 包定义字段完整性、spec 版本、Lua 语法、依赖版本化
- **隔离合规**: subos 环境隔离检查、xvm API 使用规范
- **索引注册**: xim 包注册验证
- **生命周期**: install/config/uninstall 全流程
- **功能验证**: 安装后可用性验证

### 1.2 设计原则

- **镜像结构**: `tests/` 目录与 `pkgs/` 一一对应
- **分层测试**: 从轻量级静态检查到重量级安装验证，按需选择
- **通用抽象**: 可复用的测试逻辑提取到 `tests/lib/`
- **CI 友好**: L0+L2 无需外部依赖，秒级完成

## 2. 架构

### 2.1 目录结构

```
tests/
├── conftest.py                   # pytest 全局 fixtures
├── pytest.ini                    # pytest 配置
├── lib/
│   ├── __init__.py
│   ├── xpkg_parser.py            # lua 包文件解析器
│   ├── assertions.py             # 通用断言函数
│   ├── xvm_client.py             # xvm 操作封装
│   ├── xlings_client.py          # xlings install/remove 封装
│   └── platform_utils.py         # 平台检测工具
├── a/
│   ├── test_alsa_lib.py
│   └── test_automake.py
├── b/
│   ├── test_binutils.py
│   ├── test_bison.py
│   └── test_bzip2.py
└── ...                           # 与 pkgs/ 镜像, 共 45 个测试文件
```

### 2.2 测试层级

| 层级 | 名称 | 标记 | 需要 xlings | 耗时 | 说明 |
|------|------|------|-------------|------|------|
| L0 | 静态分析 | `@mark.static` | 否 | <1s/包 | lua 语法、字段完整性、依赖版本化检查 |
| L1 | 索引注册 | `@mark.index` | 是 | <2s/包 | `xim --add-xpkg` 能否成功注册 |
| L2 | 隔离合规 | `@mark.isolation` | 否 | <1s/包 | subos 架构合规性检查 |
| L3 | 安装卸载 | `@mark.lifecycle` | 是 | 10-600s/包 | install → config → verify → uninstall |
| L4 | 功能验证 | `@mark.verify` | 是 | 5-30s/包 | 安装后程序可用性验证 |

### 2.3 fromsource 特有测试

相比主索引仓库，fromsource 增加了以下检查：

| 检查 | 说明 |
|------|------|
| `assert_lua_syntax` | 使用 `luac -p` 验证 Lua 语法（主仓库的包可能使用 xmake 语法扩展） |
| `assert_deps_versioned` | 所有依赖必须有明确版本号 `pkgname@version` |
| `assert_has_lifecycle_hooks` | 必须有 install() 和 uninstall() 函数 |
| `assert_no_direct_ld_libpath` | 不应直接设置 LD_LIBRARY_PATH（有文档化的白名单） |
| `assert_no_deprecated_libpath` | 不应使用已废弃的 XLINGS_PROGRAM_LIBPATH |

## 3. 已知问题

| 包 | 问题 | 标记 |
|---|---|---|
| python | 使用旧 API `import("common")` | `@xfail` |
| qemu | 直接调用系统包管理器 `pacman -S` | `@xfail` |
| python | LD_LIBRARY_PATH 使用（已加入白名单） | 白名单 |
| libxkbcommon | LD_LIBRARY_PATH 使用（已加入白名单） | 白名单 |
| musl-gcc | LD_LIBRARY_PATH 使用（已加入白名单） | 白名单 |
