#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage: source scripts/common.sh && apply_patch <patch_name> <target_dir>
#
# 支持两种 patch 格式:
# 1. .patch 文件: 使用 git apply --3way 应用
# 2. .sh 脚本文件: 直接调用脚本，传入 target_dir 作为参数

set -e

# 使用 $0 的位置来动态计算 build 目录（CI 和本地都适用）
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd "$SCRIPT_PATH/.." && pwd)"

apply_patch() {
    local patch_name="$1"
    local target_dir="$2"

    if [ -z "$patch_name" ] || [ -z "$target_dir" ]; then
        echo "Usage: apply_patch <patch_name> <target_dir>"
        echo "  patch_name : patches 目录下的 patch 目录名"
        echo "  target_dir : 目标项目目录"
        return 1
    fi

    # 如果 target_dir 是相对路径，基于 BUILD_DIR 转换
    if [[ "$target_dir" != /* ]]; then
        target_dir="$BUILD_DIR/$target_dir"
    fi

    # 查找 patch 目录
    local patch_dir=""
    local found_dirs=""

    for proj_dir in "$BUILD_DIR"/*/; do
        local patches_dir="${proj_dir}patches"
        if [ -d "$patches_dir" ]; then
            local candidate="${patches_dir}/${patch_name}"
            if [ -d "$candidate" ]; then
                patch_dir="$candidate"
                break
            fi
            found_dirs="${found_dirs}${patches_dir}/"$'\n'
        fi
    done

    if [ -z "$patch_dir" ]; then
        echo "Error: Patch directory not found: ${patch_name}"
        echo "Searched in:"
        echo "$found_dirs"
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Error: Target directory not found: $target_dir"
        return 1
    fi

    echo "========================================="
    echo "Patch: $patch_name"
    echo "Dir: $patch_dir"
    echo "Target: $target_dir"
    echo "========================================="

    # 检查 patch 类型
    local patches=($(ls "$patch_dir"/*.patch 2>/dev/null | sort))
    local scripts=($(ls "$patch_dir"/*.sh 2>/dev/null | sort))

    # 优先使用 .patch 文件
    if [ ${#patches[@]} -gt 0 ]; then
        echo "Patches: ${#patches[@]} file(s)"
        echo "-----------------------------------------"

        # 打印 DESCRIPTION
        local first_patch="${patches[0]}"
        local description=$(grep -m1 '^Subject:' "$first_patch" | sed 's/^Subject: \[PATCH\] //')
        if [ -n "$description" ]; then
            echo "$description"
            echo "-----------------------------------------"
        fi

        # 应用 patches（使用 git -C）
        local apply_failed=0
        for p in "${patches[@]}"; do
            echo "Applying: $(basename "$p")"
            # Capture output; --3way returns 1 on conflict but files are partially applied
            local apply_output
            if ! apply_output=$(git -C "$target_dir" apply --3way "$p" 2>&1); then
                # Check for merge conflicts left in working tree
                local conflict_files
                conflict_files=$(git -C "$target_dir" diff --name-only --diff-filter=U 2>/dev/null)
                if [ -n "$conflict_files" ]; then
                    echo "ERROR: 3-way merge conflict in:"
                    echo "$conflict_files"
                    echo "Resolve conflicts manually or update the patch."
                    # Restore to clean state so re-runs are safe
                    git -C "$target_dir" checkout -- . 2>/dev/null || true
                    git -C "$target_dir" clean -fd 2>/dev/null || true
                    return 1
                fi
                # If no conflict markers but still failed, it's a hard reject
                echo "ERROR: Failed to apply patch: $(basename "$p")"
                echo "$apply_output"
                git -C "$target_dir" checkout -- . 2>/dev/null || true
                git -C "$target_dir" clean -fd 2>/dev/null || true
                return 1
            fi
            echo "$apply_output"
        done

    # 如果没有 .patch 文件，检查 .sh 脚本
    elif [ ${#scripts[@]} -gt 0 ]; then
        echo "Scripts: ${#scripts[@]} file(s)"
        echo "-----------------------------------------"

        # 执行脚本
        for s in "${scripts[@]}"; do
            echo "Executing: $(basename "$s")"
            chmod +x "$s"
            "$s" "$target_dir"
        done

    else
        echo "Error: No .patch or .sh files found in $patch_dir"
        return 1
    fi

    echo "========================================="
    echo "Patch applied successfully!"
}