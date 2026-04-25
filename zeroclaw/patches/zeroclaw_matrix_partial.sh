#!/bin/bash
# =============================================================================
# zeroclaw-matrix-patches.sh - Matrix 通道 Stream Mode Partial 优化补丁
# =============================================================================

DESCRIPTION="Matrix StreamMode Partial 优化:
1. collapse_tool_calls: 工具调用累积到 draft，带计数
2. finalize_draft: 删除 draft，发送最终消息到原线程"

set -e

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

echo "Patching matrix.rs..."

# =============================================================================
# 修改 1-4: matrix.rs
# =============================================================================

perl -i -0pe '
s{(multi_message_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,)}
{$1\n    /// Thread context for Partial mode final message.\n    partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,};
' "$TARGET"

if ! grep -q "partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>" "$TARGET"; then
    echo "ERROR: Failed to add partial_thread_ts field"
    exit 1
fi
echo "  ✓ Added partial_thread_ts field"

perl -i -0pe '
s{(multi_message_thread_ts: Arc::new\(Mutex::new\(HashMap::new\(\)\)\),)}
{$1\n            partial_thread_ts: Arc::new(Mutex::new(HashMap::new())),};
' "$TARGET"

if ! grep -q "partial_thread_ts: Arc::new(Mutex::new(HashMap::new()))" "$TARGET"; then
    echo "ERROR: Failed to add partial_thread_ts initialization"
    exit 1
fi
echo "  ✓ Added partial_thread_ts initialization"

perl -i -0pe '
s{(\.insert\(room_id, std::time::Instant::now\(\)\);)\n\n(\s+)Ok\(Some\(event_id\)\)}
{.insert(room_id.clone(), std::time::Instant::now());\n\n$2// Save thread_ts for finalize_draft.\n                self.partial_thread_ts.lock().await.insert(room_id, message.thread_ts.clone());\n\n                Ok(Some(event_id))};
' "$TARGET"

if ! grep -q "Save thread_ts for finalize_draft" "$TARGET"; then
    echo "ERROR: Failed to add thread_ts save in send_draft"
    exit 1
fi
echo "  ✓ Added thread_ts save in send_draft"

perl -i -0pe '
s{StreamMode::Partial => \{\n\s+// Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}}
{StreamMode::Partial => {\n                self.last_draft_edit.lock().await.remove(\&room_id);\n                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id).flatten();\n                if let Err(e) = self.redact_message(\&room_id, message_id, None).await {\n                    tracing::debug!("Matrix draft deletion failed: {e}");\n                }\n                let mut msg = SendMessage::new(text, recipient);\n                msg.thread_ts = thread_ts;\n                if let Err(e) = self.send(\&msg).await {\n                    tracing::debug!("Matrix final message send failed: {e}");\n                }\n                Ok(())\n            }};
' "$TARGET"

if ! grep -q "self.redact_message" "$TARGET"; then
    echo "ERROR: Failed to modify finalize_draft"
    exit 1
fi
echo "  ✓ Modified finalize_draft"

# =============================================================================
# 修改 5: orchestrator/mod.rs - collapse_tool_calls
# =============================================================================

TARGET_ORCH="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

echo "Patching orchestrator/mod.rs..."

if ! grep -q "while let Some(text) = notify_rx.recv().await" "$TARGET_ORCH"; then
    echo "ERROR: Original notify_task code not found"
    exit 1
fi

# 使用精确匹配替换
perl -i -0pe 's/    \} else \{\n        Some\(tokio::spawn\(async move \{\n            let thread_ts = notify_thread_root;\n            while let Some\(text\) = notify_rx\.recv\(\)\.await \{\n                if let Some\(ref ch\) = notify_channel \{\n                    let _ = ch\n                        \.send\(\n                            &SendMessage::new\(&text, &notify_reply_target\)\n                                \.in_thread\(thread_ts\.clone\(\)\),\n                        \)\n                        \.await;\n                \}\n            \}\n        \}\)\)\n    \};/    } else {\n        \/\/ TOOL CALLS COLLAPSE with count and numbering\n        Some(tokio::spawn(async move {\n            let thread_ts = notify_thread_root;\n            let mut tool_calls_draft_id: Option<String> = None;\n            let mut accumulated_tool_calls = String::new();\n            while let Some(text) = notify_rx.recv().await {\n                if let Some(ref ch) = notify_channel {\n                    \/\/ Calculate line number for this tool call\n                    let num = if accumulated_tool_calls.is_empty() {\n                        1\n                    } else {\n                        accumulated_tool_calls.lines().count() + 1\n                    };\n                    \/\/ Remove original emoji and add numbering\n                    let clean_text = text.trim_start_matches("🔧 ");\n                    if !accumulated_tool_calls.is_empty() {\n                        accumulated_tool_calls.push_str("\\n");\n                    }\n                    accumulated_tool_calls.push_str(\&format!("{}. {}", num, clean_text));\n                    \n                    \/\/ Format with count in summary\n                    let count = accumulated_tool_calls.lines().count();\n                    let details_content = format!(\n                        "<details><summary>🔧 Tool Calls ({})<\/summary>\\n\\n{}\\n<\/details>",\n                        count,\n                        accumulated_tool_calls\n                    );\n                    if let Some(ref draft_id) = tool_calls_draft_id {\n                        let _ = ch.update_draft(\&notify_reply_target, draft_id, \&details_content).await;\n                    } else {\n                        if let Ok(Some(id)) = ch.send_draft(\&SendMessage::new(\&details_content, \&notify_reply_target).in_thread(thread_ts.clone())).await {\n                            tool_calls_draft_id = Some(id);\n                        }\n                    }\n                }\n            }\n        }))\n    };/' "$TARGET_ORCH"

if ! grep -q "TOOL CALLS COLLAPSE" "$TARGET_ORCH"; then
    echo "ERROR: Failed to apply orchestrator patch"
    echo "The upstream code may have changed. Please check the notify_task section."
    exit 1
fi
echo "  ✓ Modified notify_task"

echo ""
echo "========================================="
echo "Patch applied successfully!"
echo "========================================="