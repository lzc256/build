#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage: source scripts/common.sh && apply_patch <patch_name> <target_dir>
#
# 新格式: patch 目录包含 .patch 文件
# 使用 git apply --3way 进行应用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

apply_patch() {
    local patch_name="$1"
    local target_dir="$2"

    if [ -z "$patch_name" ] || [ -z "$target_dir" ]; then
        echo "Usage: apply_patch <patch_name> <target_dir>"
        echo "  patch_name : patches 目录下的 patch 目录名"
        echo "  target_dir : 目标项目目录"
        return 1
    fi

    # 查找 patch 目录
    local patch_dir=""
    local found_dirs=""

    for proj_dir in "$REPO_ROOT"/*/; do
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

    # 进入目标目录
    cd "$target_dir"

    # 应用 patches
    for p in "${patches[@]}"; do
        echo "Applying: $(basename "$p")"
        git apply --3way "$p"
    done

    echo "========================================="
    echo "Patch applied successfully!"
}