# Multi-Project Patch Framework

使用 git format-patch 对多个项目进行 patch 和构建的框架。

## 目录结构

```
.
├── scripts/
│   └── common.sh              # 公共 patch 逻辑 (git am --3way)
├── zeroclaw/                   # zeroclaw 项目
│   └── patches/
│       ├── 01-disable-high-entropy-redaction/
│       │   └── 0001-*.patch
│       ├── 02-matrix-partial-draft-thinking/
│       │   └── 0001-*.patch
│       └── 03-matrix-partial-finalize/
│           └── 0001-*.patch
├── netbird/                    # netbird 项目
│   └── patches/
│       └── 01-android-anet/
│           └── 0001-*.patch
├── .github/workflows/
│   ├── zeroclaw-docker.yml    # zeroclaw: Docker 构建
│   └── netbird-build.yml      # netbird: 二进制构建
└── README.md
```

## Patch 格式

Patch 文件使用标准 git format-patch 格式，放在 `{project}/patches/{patch-name}/` 目录中。

### 生成新的 patch ���件

1. 克隆上游仓库并创建分支:
   ```bash
   git clone https://github.com/zeroclaw-labs/zeroclaw.git zeroclaw-src
   cd zeroclaw-src
   git checkout -b my-patch
   ```

2. 手动修改代码

3. 生成 patch 文件:
   ```bash
   git format-patch <base-commit>..HEAD -o /path/to/project/patches/01-my-patch/
   ```

4. patch 目录名前缀 (`01-`, `02-`) 控制应用顺序

### 添加新项目

1. 创建项目目录和 patches 子目录：
   ```bash
   mkdir -p new-project/patches
   ```

2. 在 `patches/` 添加 patch 目录（包含 .patch 文件）

3. 创建对应的 workflow 文件

## 已有项目

### zeroclaw

| Patch | 描述 |
|-------|------|
| `01-disable-high-entropy-redaction` | 禁用 LeakDetector 高熵 token 审查 |
| `02-matrix-partial-draft-thinking` | Matrix Partial 初始 draft 占位符 |
| `03-matrix-partial-finalize` | Matrix Partial finalize_draft 优化 |

### netbird

| Patch | 描述 |
|-------|------|
| `01-android-anet` | Android 网络接口访问修复 |

## 使用方法

### 本地测试 patch

```bash
source scripts/common.sh
apply_patch <patch_name> <target_dir>

# 示例
git clone https://github.com/zeroclaw-labs/zeroclaw.git zeroclaw-src
apply_patch 01-disable-high-entropy-redaction zeroclaw-src
git diff zeroclaw-src
```

### GitHub Actions

1. 推送到 GitHub
2. 进入 Actions 页面
3. 选择对应项目的 workflow
4. 填入参数并运行

## 公共函数

### apply_patch

```bash
source scripts/common.sh
apply_patch <patch_name> <target_dir>
```

| 参数 | 说明 |
|------|------|
| `patch_name` | patches 目录下的 patch 目录名（如 `01-disable-high-entropy-redaction`）|
| `target_dir` | 目标项目目录（必须是 git 仓库）|

自动搜索所有 `{project}/patches/` 目录查找 patch 目录。

### 3-way Merge

使用 `git am --3way` 进行 3-way merge，能够：
- 自动处理上游的空白变化和行偏移
- 失败时提供清晰的冲突标记
- 通过 `git am --abort` 原子回滚