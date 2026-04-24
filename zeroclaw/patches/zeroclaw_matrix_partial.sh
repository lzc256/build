#!/bin/bash
# zeroclaw-matrix-patches: Matrix 通道的 Stream Mode Partial 相关补丁
#
# 功能：
# 1. 工具调用累积到 draft 消息，包裹在 <details> 块中（而非每调用一次发一条消息）
# 2. 最终回复更新 draft 为 "Done!"，并发送最终消息到原消息列
#
# 工作原理：
# - send_draft: 发送初始 draft，保存 thread_ts（用于后续线程回复）
# - collapse_tool_calls: 拦截工具调用通知，累积到 draft 消息中
# - finalize_draft: 更新 draft 为 "Done!"，发送最终消息到原消息列
#
# 依赖：
# - zeroclaw 配置: [channels].show_tool_calls = true
# - stream_mode = partial
#
# 注意事项：
# - 如果 zeroclaw 上游修改了相关代码，需要手动更新此 patch
# - 关键代码位置（用于搜索）：
#   - send_draft Partial 分支: ~line 1624
#   - notify_task else 分支: ~line 2981
#   - finalize_draft Partial 分支: ~line 1820

DESCRIPTION="\
合并 patch: Matrix StreamMode Partial 优化
1. collapse_tool_calls: 工具调用累积到 draft，包裹在 <details> 块
2. finalize_draft: 更新 draft 为 Done!，发送最终消息到原消息列"

# ============================================================
# 修改 1: matrix.rs - 字段和构造函数
# ============================================================

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

# 1a. 添加 partial_thread_ts 字段到结构体
# 位置: multi_message_thread_ts 字段后面
# 用途: 保存 thread_ts 用于 final message 回复到原消息列
perl -i -0pe '
s{(multi_message_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,)}
{$1
    /// Thread context for Partial mode final message (enables reply to original message column).
    /// Key: room_id (extracted from recipient), Value: thread_ts from original message.
    partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,};
' "$TARGET"

# 1b. 构造函数中初始化 partial_thread_ts
# 位置: multi_message_thread_ts 初始化后面
perl -i -0pe '
s{(multi_message_thread_ts: Arc::new\(Mutex::new\(HashMap::new\(\)\)\),)}
{$1
            partial_thread_ts: Arc::new(Mutex::new(HashMap::new())),};
' "$TARGET"

# ============================================================
# 修改 2: matrix.rs - send_draft Partial 分支
# ============================================================
# 保存 thread_ts 到 partial_thread_ts HashMap
# Key 使用 room_id（extract_room_id 转换后的），与 finalize_draft 保持一致

# 1c. 在 send_draft 的 Partial 分支中保存 thread_ts
# 注意: insert 使用 room_id.clone() 因为后面还要用 room_id
# 修复: 确保 Key 使用 extract_room_id 转换后的 room_id
perl -i -0pe '
s{(\.insert\(room_id, std::time::Instant::now\(\)\);)\n\n(\s+)Ok\(Some\(event_id\)\)}
{.insert(room_id.clone(), std::time::Instant::now());

$2// Save thread_ts for finalize_draft to reply to original message column.
                // Key must match: use room_id (extracted from recipient) same as in finalize_draft.
                self.partial_thread_ts.lock().await.insert(room_id, message.thread_ts.clone());

                Ok(Some(event_id))};
' "$TARGET"

# ============================================================
# 修改 3: matrix.rs - finalize_draft Partial 分支
# ============================================================
# 更新 draft 为 "Done!"，发送最终消息到原消息列

perl -i -0pe '
# 1d. 修改 finalize_draft 中 Partial 分支
# 关键修复: 使用 room_id（extract_room_id 转换后的）作为 Key 获取 thread_ts
s{StreamMode::Partial => \{\n\s+// Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}}
{StreamMode::Partial => {
                // Step 1: Clear rate limit entry
                self.last_draft_edit.lock().await.remove(\&room_id);
                
                // Step 2: Get thread_ts for replying to original message column.
                // IMPORTANT: Use room_id (extracted from recipient) as key, same as send_draft.
                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id).flatten();
                
                // Step 3: Update draft with "Done!" marker (do NOT delete - keeps history)
                let done_content = "**Done!**";
                if let Err(e) = self.edit_message(\&room_id, message_id, done_content).await {
                    tracing::debug!("Matrix draft Done update failed: {e}");
                }
                
                // Step 4: Send final message in thread, replying to original message column.
                // The thread_ts was captured from the original message in send_draft.
                let mut msg = SendMessage::new(text, recipient);
                msg.thread_ts = thread_ts;
                if let Err(e) = self.send(\&msg).await {
                    tracing::debug!("Matrix final message send failed: {e}");
                }
                Ok(())
            }};
' "$TARGET"

# ============================================================
# 修改 4: orchestrator/mod.rs - collapse_tool_calls
# ============================================================
# 工具调用累积到 draft 消息，包裹在 <details> 块中

TARGET_ORCH="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

# 2. 修改 notify_task 的 else 分支（~line 2981-2995）
# 原始代码: 每收到工具调用通知就发送一条独立消息
# 修改后: 累积到 draft 消息中，包裹在 <details> 块

# 先备份
cp "$TARGET_ORCH" "${TARGET_ORCH}.bak"

awk '
# 替换 notify_task 的 else 分支（行 2981-2995）
NR == 2981 {
    print "    } else {"
    print "        // Collapse tool calls: accumulate in draft message with <details> block"
    print "        Some(tokio::spawn(async move {"
    print "            let thread_ts = notify_thread_root;"
    print "            let mut tool_calls_draft_id: Option<String> = None;"
    print "            let mut accumulated_tool_calls = String::new();"
    print "            while let Some(text) = notify_rx.recv().await {"
    print "                if let Some(ref ch) = notify_channel {"
    print "                    // Append tool call to accumulated string"
    print "                    if !accumulated_tool_calls.is_empty() {"
    print "                        accumulated_tool_calls.push_str(\"\\n\");"
    print "                    }"
    print "                    accumulated_tool_calls.push_str(&text);"
    print "                    "
    print "                    // Wrap in <details> block for collapsible display"
    print "                    let details_content = format!("
    print "                        \"<details><summary>🔧 Tool Calls</summary>\\n\\n{}\\n</details>\","
    print "                        accumulated_tool_calls"
    print "                    );"
    print "                    "
    print "                    // Use update_draft if draft_id exists, otherwise send initial draft"
    print "                    if let Some(ref draft_id) = tool_calls_draft_id {"
    print "                        let _ = ch.update_draft(&notify_reply_target, draft_id, &details_content).await;"
    print "                    } else {"
    print "                        // Send initial draft with tool calls"
    print "                        if let Ok(Some(id)) = ch.send_draft(&SendMessage::new(&details_content, &notify_reply_target).in_thread(thread_ts.clone())).await {"
    print "                            tool_calls_draft_id = Some(id);"
    print "                        }"
    print "                    }"
    print "                }"
    print "            }"
    print "        }))"
    print "    };"
    next
}
# 跳过原始 else 分支的内容（行 2982-2995）
NR >= 2982 && NR <= 2995 { next }
{ print }
' "${TARGET_ORCH}.bak" > "$TARGET_ORCH"

rm -f "${TARGET_ORCH}.bak"

echo ""
echo "========================================="
echo "Patch applied successfully!"
echo "========================================="
echo ""
echo "Modified files:"
echo "  - $TARGET"
echo "  - $TARGET_ORCH"
echo ""
echo "Changes:"
echo "  1. matrix.rs: Added partial_thread_ts field"
echo "  2. matrix.rs: save_draft saves thread_ts with room_id key"
echo "  3. matrix.rs: finalize_draft updates draft to Done! and sends final message"
echo "  4. orchestrator/mod.rs: Tool calls accumulate in draft with <details> block"
