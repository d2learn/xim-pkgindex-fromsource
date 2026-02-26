# CI Workflow 说明

## 概述

xpkg fromsource 测试通过 GitHub Actions 自动运行。

## Workflow 文件

| Workflow | 文件 | 关注点 |
|----------|------|--------|
| `ci-xpkg-test.yml` | 新增 | **全量**静态分析 + 隔离合规 + 索引注册 |
| `ci-test.yml` | 兼容原有 | 变更文件的 `xim --add-xpkg` 验证 + LD_LIBRARY_PATH lint |

## 触发条件

```yaml
on:
  push:
    paths: ['pkgs/**', 'tests/**']
  pull_request:
    paths: ['pkgs/**', 'tests/**']
```

## Job 结构

```
┌─────────────────────────┐
│  static-and-isolation   │  L0 + L2
│  ・无需 xlings           │  ~10 秒
│  ・Python + pytest + lua │
└───────────┬─────────────┘
            │ needs
            ▼
┌─────────────────────────┐
│  index-registration     │  L1
│  ・需要安装 xlings       │  ~30 秒
│  ・xim --add-xpkg 验证  │
└─────────────────────────┘
```

### Job 1: `static-and-isolation`

**不需要 xlings**，纯 Python 静态分析。

| Step | 说明 |
|------|------|
| Checkout | 拉取代码 |
| Setup Python 3.12 | 安装 Python |
| Install dependencies | `pip install pytest` + lua5.4 |
| **L0 Static Analysis** | `pytest tests/ -m static --tb=short -q` |
| **L2 Isolation Compliance** | `pytest tests/ -m isolation --tb=short -q` |
| **Lint libpath policy** | `check-no-direct-ld-libpath.sh` |

检查内容:
- 包定义字段完整性 (name, description, type, spec)
- spec/type 值合法性
- Lua 语法正确性
- 依赖版本化 (所有 deps 必须有 @version)
- 拼写错误检查
- subos 隔离合规 (xvm API、shell 配置、PATH 修改、LD_LIBRARY_PATH)

### Job 2: `index-registration`

**需要 xlings**，依赖 Job 1 通过后才运行。

| Step | 说明 |
|------|------|
| Checkout | 拉取代码 |
| Setup Python 3.12 | 安装 Python |
| Install pytest | `pip install pytest` |
| Install xlings | 非交互安装 (`XLINGS_NON_INTERACTIVE=1`) |
| **L1 Index Registration** | `pytest tests/ -m index --tb=short -q` |

## 本地运行

```bash
# 完全等同于 CI Job 1
pip install pytest
pytest tests/ -m static --tb=short -q
pytest tests/ -m isolation --tb=short -q
bash .github/scripts/check-no-direct-ld-libpath.sh

# 完全等同于 CI Job 2 (需要 xlings)
pytest tests/ -m index --tb=short -q
```

## L3/L4 测试

L3 (生命周期) 和 L4 (功能验证) 目前**不在 CI 中运行**，因为:
- fromsource 包需要实际从源码编译（非常耗时，通常 10-600 秒/包）
- 需要完整的构建工具链
- 部分包依赖 XLINGS_RES 资源服务器

手动运行:

```bash
# 安装并验证单个包
pytest tests/z/test_zlib.py -m "lifecycle or verify" -v

# 全量安装验证 (非常耗时)
pytest tests/ -m "lifecycle or verify" --timeout=600
```
