#!/bin/bash
# =============================================================================
# channel_matrix_partial_draft_Thinking.sh - Matrix Partial 初始 draft 占位符优化
# =============================================================================

DESCRIPTION="Matrix StreamMode Partial 初始 draft 占位符优化:
- 将初始 draft 内容从 '...' 改为 '💬 Thinking...'
- 保持原有缩进不变"

set -e

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

echo "Patching matrix.rs initial draft..."

perl -i -pe 's/^(\s+)("\.\.\.")$/$1"💬 Thinking..."/ if /"\.\.\."/ && !/Send initial/' "$TARGET"

if ! grep -q "💬 Thinking" "$TARGET"; then
    echo "ERROR: Failed to change initial draft text"
    exit 1
fi
echo "  ✓ Changed initial draft to 💬 Thinking..."

echo ""
echo "========================================="
echo "Patch applied successfully!"
echo "========================================="