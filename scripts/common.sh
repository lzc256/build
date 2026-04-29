#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage: source scripts/common.sh && apply_patch <patch_name> <target_dir>
#
# 新格式: patch 目录包含 .patch 文件
# 使用 git apply --3way 进行应用

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

    # 查找 .patch 文件
    local patches=($(ls "$patch_dir"/*.patch 2>/dev/null | sort))
    if [ ${#patches[@]} -eq 0 ]; then
        echo "Error: No .patch files found in $patch_dir"
        return 1
    fi

    echo "========================================="
    echo "Patch: $patch_name"
    echo "Dir: $patch_dir"
    echo "Target: $target_dir"
    echo "Patches: ${#patches[@]} file(s)"
    echo "========================================="

    # 打印 DESCRIPTION
    local first_patch="${patches[0]}"
    local description=$(grep -m1 '^Subject:' "$first_patch" | sed 's/^Subject: \[PATCH\] //')
    if [ -n "$description" ]; then
        echo ""
        echo "$description"
        echo "-----------------------------------------"
    fi

    # 应用 patches（使用 git -C）
    for p in "${patches[@]}"; do
        echo "Applying: $(basename "$p")"
        git -C "$target_dir" apply --3way "$p"
    done

    echo "========================================="
    echo "Patch applied successfully!"
}