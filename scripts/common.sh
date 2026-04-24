#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage: source scripts/common.sh && apply_patch <patch_name> <target_dir>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply_patch() {
    local patch_name="$1"
    local target_dir="$2"

    if [ -z "$patch_name" ] || [ -z "$target_dir" ]; then
        echo "Usage: apply_patch <patch_name> <target_dir>"
        echo "  patch_name : patch 目录下的 .sh 文件名（不含后缀）"
        echo "  target_dir : 目标项目目录"
        return 1
    fi

    # 查找 patch 文件（支持多项目）
    local patch_file=""
    for dir in "$SCRIPT_DIR"/../*/patches; do
        if [ -f "${dir}/${patch_name}.sh" ]; then
            patch_file="${dir}/${patch_name}.sh"
            break
        fi
    done

    if [ -z "$patch_file" ]; then
        echo "Error: Patch not found: ${patch_name}.sh"
        echo "Searched in:"
        for dir in "$SCRIPT_DIR"/../*/patches; do
            echo "  - $(dirname "$dir")/patches/"
        done
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Error: Target directory not found: $target_dir"
        return 1
    fi

    echo "========================================="
    echo "Patch: $patch_name"
    echo "File: $patch_file"
    echo "Target: $target_dir"
    echo "========================================="

    # 打印 DESCRIPTION
    local description=$(grep -m1 '^DESCRIPTION=' "$patch_file" | cut -d'"' -f2)
    if [ -n "$description" ]; then
        echo ""
        echo "$description"
        echo "-----------------------------------------"
    fi

    # 执行 patch
    bash "$patch_file" "$target_dir"

    echo "========================================="
    echo "Patch applied successfully!"
}
