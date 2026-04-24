# Multi-Project Patch Framework

使用脚本对多个项目进行 patch 和构建的框架。

## 目录结构

```
.
├── scripts/
│   └── common.sh              # 公共 patch 逻辑
├── zeroclaw/                   # zeroclaw 项目
│   └── patches/
│       ├── finalize_draft.sh
│       ├── fix_memory.sh
│       └── remove_debug.sh
├── other-project/              # 其他项目（示例）
│   └── patches/
├── .github/workflows/
│   ├── zeroclaw-docker.yml    # zeroclaw: Docker 构建
│   └── other-build.yml        # 其他项目: 二进制构建
└── README.md
```

## 添加新项目

1. 创建项目目录和 patches 子目录：
   ```bash
   mkdir -p new-project/patches
   ```

2. 在 `patches/` 添加 patch 脚本（见下文）

3. 创建对应的 workflow 文件：
   ```bash
   # .github/workflows/newproject.yml
   ```

## Patch 脚本格式

```bash
#!/bin/bash
DESCRIPTION="\
详细描述 patch 的用途和实现方式:
- 第一点说明
- 第二点说明"

# 对单个文件应用 sed/perl 替换
sed -i '' 's/old/new/' "$1/src/file.rs"

# 对多个文件应用替换
for f in "$1"/*.c; do
    sed -i '' 's/old/new/' "$f"
done
```

## 已有项目

### zeroclaw

| Patch | 描述 |
|-------|------|
| `finalize_draft` | Partial 模式下删除 draft 并发送最终消息 |
| `fix_memory` | malloc/calloc 替换为 xmalloc/xcalloc |
| `remove_debug` | 移除调试 printf 语句 |

### other-project

占位示例，请根据实际项目添加 patch。

## 使用方法

### 本地测试 patch

```bash
source scripts/common.sh
apply_patch <patch_name> <target_dir>

# 示例
git clone https://github.com/zeroclaw-labs/zeroclaw.git zeroclaw
apply_patch finalize_draft zeroclaw
git diff zeroclaw
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
| `patch_name` | patches 目录下的 .sh 文件名（不含后缀） |
| `target_dir` | 目标项目目录 |

自动搜索所有 `{project}/patches/` 目录查找 patch 文件。
