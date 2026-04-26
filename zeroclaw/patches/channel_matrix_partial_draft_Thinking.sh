#!/bin/bash
# =============================================================================
# channel_matrix_partial_draft_Thinking.sh - Matrix Partial 初始 draft 占位符优化
# =============================================================================

DESCRIPTION="Matrix StreamMode Partial 初始 draft 占位符优化:
- orchestrator 调用 send_draft 时传入空内容（而非 '...'）
- matrix.rs 空内容分支返回 '💬 Thinking...' 作为占位符"

set -e

TARGET_MATRIX="$1/crates/zeroclaw-channels/src/matrix.rs"
TARGET_ORCH="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

echo "Patching orchestrator/mod.rs send_draft call..."

perl -i -pe 's/SendMessage::new\("\.\.\.",/SendMessage::new("",/' "$TARGET_ORCH"

if grep -q 'SendMessage::new("",' "$TARGET_ORCH"; then
    echo "  ✓ Changed orchestrator send_draft call to empty content"
else
    echo "ERROR: Failed to change orchestrator send_draft call"
    exit 1
fi

echo "Patching matrix.rs initial draft placeholder..."

perl -i -pe 's/^(\s+)("\.\.\.")$/$1"💬 Thinking..."/ if /"\.\.\."/ && !/Send initial/' "$TARGET_MATRIX"

if grep -q "💬 Thinking" "$TARGET_MATRIX"; then
    echo "  ✓ Changed initial draft placeholder to 💬 Thinking..."
else
    echo "ERROR: Failed to change initial draft placeholder"
    exit 1
fi

echo ""
echo "========================================="
echo "Patch applied successfully!"
echo "========================================="
