# AGENTS.md — Multi-Project Patch Framework

本仓库用于对上游项目打补丁并构建。不包含业务代码，只有 patch 脚本和 CI 配置。

## Patch 脚本

位置：`<project>/patches/<name>.sh`

```bash
#!/bin/bash
DESCRIPTION="\
补丁用途说明:
- 第一点
- 第二点"

# $1 是目标目录
sed -i '' 's/old/new/' "$1/src/file.rs"      # BSD/macOS 语法
perl -i -0pe 's/multi\nline/replace/s' "$1"   # 多行替换
```

本地测试：
```bash
git clone https://github.com/upstream/project.git project-src
source scripts/common.sh
apply_patch <patch_name> project-src
git -C project-src diff
```

**注意**：`sed -i ''` 是 BSD 语法，Linux 上用 `sed -i`。CI 运行在 Ubuntu，但本地 macOS 需要 BSD 语法。推荐用 `perl -i -0pe` 保证跨平台。

## 添加新项目

1. 创建目录：`mkdir -p <project>/patches`
2. 添加 patch 脚本到 `patches/`
3. 创建 workflow：`.github/workflows/<project>.yml`
4. workflow 中调用：
   ```bash
   source scripts/common.sh
   apply_patch <patch_name> <target_dir>
   ```

## CI Workflows

| Workflow | 上游仓库 | 产物 |
|----------|----------|------|
| `zeroclaw-docker.yml` | `zeroclaw-labs/zeroclaw` | Docker 镜像 |
| `stealthpanda-build.yml` | `we-be/stealthpanda` | 二进制 |
| `netbird-build.yml` | `netbirdio/netbird` | `netbird-anet-linux-arm64` |
| `other-build.yml` | 模板 | — |

### zeroclaw 构建参数

- Rust: `1.93.0`
- Features: `channel-matrix,channel-lark,whatsapp-web`
- Target: `x86_64-unknown-linux-gnu`
- Docker: `ghcr.io/<repo>:zeroclaw-<tag>-debian`

### stealthpanda 构建参数

- Zig: `0.15.2`
- 产物: `zig-out/bin/lightpanda`

### netbird 构建参数

- Go: 从 `go.mod` 读取
- Target: `linux/arm64`
- 依赖替换: `github.com/wlynxg/anet` → `github.com/lzc256/anet@latest`
- 产物: `netbird-anet-linux-arm64`
- 保留: 90 天

## 目录说明

| 目录 | 说明 |
|------|------|
| `scripts/` | `common.sh` — `apply_patch` 函数 |
| `*/patches/` | 各项目的补丁脚本 |
| `*-src/` | 克隆的上游源码（gitignored） |
