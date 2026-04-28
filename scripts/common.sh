#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage: source scripts/common.sh && apply_patch <patch_name> <target_dir>
#
# 新格式: patch 目录包含 .patch 文件 (git format-patch 格式)
# 使用 git am --3way 进行 3-way merge，更能容忍上游变化

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

apply_patch() {
    local patch_name="$1"
    local target_dir="$2"

    if [ -z "$patch_name" ] || [ -z "$target_dir" ]; then
        echo "Usage: apply_patch <patch_name> <target_dir>"
        echo "  patch_name : patches 目录下的 patch 目录名"
        echo "  target_dir : 目标项目目录 (必须是 git 仓库)"
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

    # 检查目标目录是否是 git 仓库
    if [ ! -d "$target_dir/.git" ]; then
        echo "Error: Target is not a git repository: $target_dir"
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

    # 打印 DESCRIPTION (从第一个 .patch 文件中读取 Subject)
    local first_patch="${patches[0]}"
    local description=$(grep -m1 '^Subject:' "$first_patch" | sed 's/^Subject: \[PATCH\] //')
    if [ -n "$description" ]; then
        echo ""
        echo "$description"
        echo "-----------------------------------------"
    fi

    # 进入目标目录
    cd "$target_dir"

    # 获取当前分支名
    local original_branch=$(git rev-parse --abbrev-ref HEAD)

    # 创建安全分支用于回滚
    local safety_branch="pre-patch-$(date +%s)"
    git checkout -b "$safety_branch" >/dev/null 2>&1

    # 应用 patches
    local failed=0
    for p in "${patches[@]}"; do
        echo "Applying: $(basename "$p")"
        if ! git am --3way --keep-cr --no-gpg-sign < "$p"; then
            echo "ERROR: Failed to apply $(basename "$p")"
            echo "Attempting rollback..."
            git am --abort >/dev/null 2>&1 || true
            git checkout "$original_branch" >/dev/null 2>&1 || git checkout - >/dev/null 2>&1 || true
            git branch -D "$safety_branch" >/dev/null 2>&1 || true
            echo "Rollback complete."
            return 1
        fi
    done

    # 成功: 切换回原分支并 fast-forward
    git checkout "$original_branch" >/dev/null 2>&1 || git checkout - >/dev/null 2>&1 || true
    git merge --ff-only "$safety_branch" >/dev/null 2>&1 || true
    git branch -D "$safety_branch" >/dev/null 2>&1 || true

    echo "========================================="
    echo "Patch applied successfully!"
}