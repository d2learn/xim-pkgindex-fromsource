# xpkg fromsource 测试使用指南

## 快速开始

### 环境准备

```bash
pip install pytest
sudo apt-get install lua5.4  # 可选，用于 Lua 语法检查
```

### 运行测试

```bash
# 静态检查 (不需要 xlings, 秒级完成)
pytest tests/ -m static

# 隔离合规检查
pytest tests/ -m isolation

# 静态 + 隔离 一起跑
pytest tests/ -m "static or isolation"

# 索引注册检查 (需要 xlings 已安装)
pytest tests/ -m index

# 安装生命周期 (需要 xlings, 会实际从源码构建包)
pytest tests/ -m lifecycle

# 功能验证 (需要包已安装)
pytest tests/ -m verify

# 全部
pytest tests/
```

### 测试单个包

```bash
# zlib 的所有测试
pytest tests/z/test_zlib.py

# gcc 只跑静态检查
pytest tests/g/test_gcc.py -m static

# 同时测多个包
pytest tests/g/test_gcc.py tests/g/test_glibc.py -m "static or isolation"
```

### 查看详细输出

```bash
# 显示每个测试名称
pytest tests/ -m static -v

# 失败时显示详细错误
pytest tests/ -m isolation --tb=long

# 只显示失败的
pytest tests/ -m isolation --tb=short -q
```

## 为新包添加测试

当你向 `pkgs/` 添加了一个新的 fromsource 包文件，需要在 `tests/` 中添加对应的测试。

### 步骤 1: 创建测试文件

测试文件路径必须与包文件路径对应:

```
pkgs/n/mypackage.lua  →  tests/n/test_mypackage.py
```

> 注意: 文件名中的 `-` 替换为 `_` (Python 模块命名规范)

### 步骤 2: 编写测试

最小模板 — 只需改 3 处 (`PKG`, `PKG_FILE`, docstring):

```python
"""测试 mypackage 包 (fromsource)"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_lua_syntax, assert_deps_versioned,
    assert_has_lifecycle_hooks,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_ld_libpath, assert_no_deprecated_libpath,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "mypackage"                    # ← 包名
PKG_FILE = "pkgs/n/mypackage.lua"    # ← 包文件相对路径


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_lua_syntax(self):
        assert_lua_syntax(PKG_FILE)

    @pytest.mark.static
    def test_deps_versioned(self, meta):
        assert_deps_versioned(meta)

    @pytest.mark.static
    def test_lifecycle_hooks(self, meta):
        assert_has_lifecycle_hooks(meta)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_ld_libpath(self):
        assert_no_direct_ld_libpath(PKG_FILE)

    @pytest.mark.isolation
    def test_no_deprecated_libpath(self):
        assert_no_deprecated_libpath(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)
```

### 步骤 3: 运行验证

```bash
# 先跑静态 + 隔离，确保包定义合规
pytest tests/n/test_mypackage.py -m "static or isolation" -v

# 再跑索引注册
pytest tests/n/test_mypackage.py -m index -v
```

## 依赖版本规范

fromsource 仓库要求所有依赖必须有明确版本号:

```lua
-- ✅ 正确
deps = { "gcc@15.1.0", "make@4.3", "zlib@1.3.1" }

-- ❌ 错误 (会被 assert_deps_versioned 检测)
deps = { "gcc", "make", "zlib" }
```

## LD_LIBRARY_PATH 白名单

以下包允许直接设置 LD_LIBRARY_PATH (在 `.github/scripts/check-no-direct-ld-libpath.sh` 和 `tests/lib/assertions.py` 中维护):

| 包 | 原因 |
|----|------|
| musl-gcc | musl 动态链接器包装器，RPATH 不适用 |
| python | 运行时需要 subos lib 路径 (libstdc++.so.6) |
| libxkbcommon | 构建时需要 subos lib 路径 |
