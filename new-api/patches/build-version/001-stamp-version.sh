#!/bin/bash
DESCRIPTION="Stamp frontend and backend version with upstream commit date (Asia/Shanghai) and short hash"
set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target_dir>}"
# Use the checked-out source revision, never the framework revision or build time.
# Dockerfile reads VERSION for both VITE_REACT_APP_VERSION and common.Version.
COMMIT_DATE=$(TZ=Asia/Shanghai git -C "$TARGET_DIR" log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M:%S')
SHORT_COMMIT=$(git -C "$TARGET_DIR" rev-parse --short=7 HEAD)
BUILD_VERSION="$COMMIT_DATE ($SHORT_COMMIT)"
printf '%s\n' "$BUILD_VERSION" > "$TARGET_DIR/VERSION"
printf 'Build version (Asia/Shanghai): %s\n' "$BUILD_VERSION"
