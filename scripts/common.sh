#!/bin/bash
# common.sh - 公共 patch 逻辑
# Usage:
#   source scripts/common.sh
#   apply_patch <patch_name> <target_dir>           # 应用单个 patch
#   apply_all_patches <project_name> <target_dir>   # 按目录名排序应用项目下所有 patch
#
# 支持 .patch 和 .sh 混合，按文件名排序依次执行:
# - .patch: git apply --3way
# - .sh: 直接调用脚本，传入 target_dir 作为参数

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

    # .patch and .sh are applied in filename order, so one directory can
    # fetch a dependency first, add static files, then wire existing files.
    local entries=()
    while IFS= read -r entry; do
        [ -n "$entry" ] && entries+=("$entry")
    done < <(find "$patch_dir" -maxdepth 1 -type f \
        \( -name '*.patch' -o -name '*.sh' \) -print | sort)

    if [ ${#entries[@]} -eq 0 ]; then
        echo "Error: No .patch or .sh files found in $patch_dir"
        return 1
    fi

    echo "Entries: ${#entries[@]} file(s)"
    echo "-----------------------------------------"

    local first_patch=""
    for entry in "${entries[@]}"; do
        case "$entry" in
            *.patch) first_patch="$entry"; break ;;
        esac
    done
    if [ -n "$first_patch" ]; then
        local description=$(grep -m1 '^Subject:' "$first_patch" | sed 's/^Subject: \[PATCH\] //')
        if [ -n "$description" ]; then
            echo "$description"
            echo "-----------------------------------------"
        fi
    fi

    for entry in "${entries[@]}"; do
        case "$entry" in
            *.patch)
                echo "Applying: $(basename "$entry")"
                git -C "$target_dir" apply --3way "$entry"
                ;;
            *.sh)
                echo "Executing: $(basename "$entry")"
                chmod +x "$entry"
                "$entry" "$target_dir"
                ;;
        esac
    done

    echo "========================================="
    echo "Patch applied successfully!"
}

# 按目录名排序，依次应用某个项目 patches/ 下的所有 patch
apply_all_patches() {
    local project_name="$1"
    local target_dir="$2"

    if [ -z "$project_name" ] || [ -z "$target_dir" ]; then
        echo "Usage: apply_all_patches <project_name> <target_dir>"
        echo "  project_name : 项目目录名（如 hermes, new-api）"
        echo "  target_dir   : 目标项目目录"
        return 1
    fi

    if [[ "$target_dir" != /* ]]; then
        target_dir="$BUILD_DIR/$target_dir"
    fi

    local patches_root="$BUILD_DIR/$project_name/patches"
    if [ ! -d "$patches_root" ]; then
        echo "Error: Patches directory not found: $patches_root"
        return 1
    fi

    # 收集所有 patch 子目录，按目录名排序；*.disabled 是暂时停用的补丁，跳过
    local patch_dirs=($(ls -d "$patches_root"/*/ 2>/dev/null | grep -v '\.disabled/$' | sort))
    if [ ${#patch_dirs[@]} -eq 0 ]; then
        echo "Error: No patch directories found under $patches_root"
        return 1
    fi

    echo "========================================="
    echo "Applying all patches for: $project_name"
    echo "Patch count: ${#patch_dirs[@]}"
    echo "Target: $target_dir"
    echo "========================================="

    for pd in "${patch_dirs[@]}"; do
        local patch_name=$(basename "$pd")
        apply_patch "$patch_name" "$target_dir"
    done

    echo "========================================="
    echo "All ${#patch_dirs[@]} patches applied successfully!"
}
