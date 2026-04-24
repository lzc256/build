#!/bin/bash
# =============================================================================
# zeroclaw-matrix-patches.sh - Matrix 通道 Stream Mode Partial 优化补丁
# =============================================================================
#
# 适用: zeroclaw-labs/zeroclaw
# 目录: zeroclaw/patches/
#
# -----------------------------------------------------------------------------
# 功能说明
# -----------------------------------------------------------------------------
#
# 本补丁实现两个优化：
#
# 1. [工具调用折叠] Tool Calls Collapse
#    当配置 [channels].show_tool_calls = true 时，AI 调用工具会发送通知。
#    原始行为：每调用一次工具就发送一条独立消息，导致消息列表刷屏。
#    优化行为：工具调用累积到一条 draft 消息中，包裹在 <details> 块内。
#
# 2. [最终回复优化] Final Reply Optimization
#    原始行为：模型完成后编辑 draft 消息，内容包含完整回复。
#    优化行为：模型完成后删除 draft 消息，在原消息列发送最终回复。
#
# -----------------------------------------------------------------------------
# 工作原理
# -----------------------------------------------------------------------------
#
# Matrix 支持消息线程（Thread）机制：
# - 根消息（root message）
# - 回复消息（reply messages）
#
# 流程：
# 1. 用户发送消息
# 2. zeroclaw 创建 draft（send_draft），保存 thread_ts
# 3. 模型流式生成，更新 draft（update_draft）
# 4. 模型调用工具 → 工具调用累积到 draft（collapse_tool_calls）
# 5. 模型完成 → 删除 draft，发送最终回复（finalize_draft）
#
# -----------------------------------------------------------------------------
# 代码位置
# -----------------------------------------------------------------------------
#
# 文件: crates/zeroclaw-channels/src/matrix.rs
#   - 字段定义（约第 63 行）: MatrixChannel 结构体
#   - 构造函数（约第 273 行）: MatrixChannel::new()
#   - send_draft（约第 1624 行）: Partial 分支
#   - finalize_draft（约第 1820 行）: Partial 分支
#
# 文件: crates/zeroclaw-channels/src/orchestrator/mod.rs
#   - notify_task（约第 2977 行）: 工具调用通知处理
#
# -----------------------------------------------------------------------------
# 依赖配置
# -----------------------------------------------------------------------------
#
# zeroclaw 配置文件 (config.toml):
#
#   [channels]
#   show_tool_calls = true    # 启用工具调用通知
#
#   [channels.matrix]
#   stream_mode = "partial"    # 启用流式 draft 模式
#
# -----------------------------------------------------------------------------

DESCRIPTION="Matrix StreamMode Partial 优化:
1. collapse_tool_calls: 工具调用累积到 draft
2. finalize_draft: 删除 draft，发送最终消息"

# =============================================================================
# 修改 1: matrix.rs - 添加 partial_thread_ts 字段
# =============================================================================
#
# 为什么需要这个字段？
# Matrix 的线程机制要求回复消息携带 thread_ts（线程根消息 ID）。
# 当用户消息在线程中时，send_draft 被调用时 message.thread_ts 包含该线程的根消息 ID。
# 我们需要保存这个值，以便 finalize_draft 时能够正确地将最终回复发送到同一线程。
#
# 数据结构：HashMap<room_id, Option<thread_ts>>
# - Key: room_id (聊天室 ID)
# - Value: thread_ts (线程根消息 ID，可为空)
#

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

# 1a. 添加字段定义
perl -i -0pe '
s{(multi_message_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,)}
{$1
    /// Thread context for Partial mode final message (enables reply to original thread).
    /// Key: room_id (extracted from recipient), Value: thread_ts from original message.
    partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,};
' "$TARGET"

# 1b. 构造函数初始化
perl -i -0pe '
s{(multi_message_thread_ts: Arc::new\(Mutex::new\(HashMap::new\(\)\)\),)}
{$1
            partial_thread_ts: Arc::new(Mutex::new(HashMap::new())),};
' "$TARGET"

# =============================================================================
# 修改 2: matrix.rs - send_draft 保存 thread_ts
# =============================================================================
#
# 位置: send_draft 方法的 Partial 分支
# 时机: 首次发送 draft 消息时
#
# 实现: 将 message.thread_ts 保存到 partial_thread_ts HashMap
# Key 使用 room_id（与 finalize_draft 保持一致）
#

# 在 insert(room_id, ...) 之后保存 thread_ts
perl -i -0pe '
s{(\.insert\(room_id, std::time::Instant::now\(\)\);)\n\n(\s+)Ok\(Some\(event_id\)\)}
{.insert(room_id.clone(), std::time::Instant::now());

$2// Save thread_ts for finalize_draft to reply to the original thread.
                self.partial_thread_ts.lock().await.insert(room_id, message.thread_ts.clone());

                Ok(Some(event_id))};
' "$TARGET"

# =============================================================================
# 修改 3: matrix.rs - finalize_draft 删除 draft
# =============================================================================
#
# 位置: finalize_draft 方法的 Partial 分支
#
# 原始行为:
#   self.edit_message(&room_id, message_id, text).await
#   → 用最终内容替换 draft 消息
#
# 优化后行为:
#   1. 清除 rate limit entry
#   2. 获取 thread_ts
#   3. 删除 draft 消息（redact_message）
#   4. 发送最终消息到原线程（send）
#
# 为什么删除而不是编辑:
# - Draft 消息通常以 "..." 开头，不够优雅
# - 用户查看历史时，看到最终回复即可
# - 保持对话流干净
#

perl -i -0pe '
s{StreamMode::Partial => \{\n\s+// Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}}
{StreamMode::Partial => {
                // Step 1: Clear rate limit entry
                self.last_draft_edit.lock().await.remove(\&room_id);
                
                // Step 2: Get thread_ts for replying to the original thread
                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id).flatten();
                
                // Step 3: Delete the draft message (do NOT keep it)
                if let Err(e) = self.redact_message(\&room_id, message_id, None).await {
                    tracing::debug!("Matrix draft deletion failed: {e}");
                }
                
                // Step 4: Send final message as a new message in the original thread
                let mut msg = SendMessage::new(text, recipient);
                msg.thread_ts = thread_ts;
                if let Err(e) = self.send(\&msg).await {
                    tracing::debug!("Matrix final message send failed: {e}");
                }
                Ok(())
            }};
' "$TARGET"

# =============================================================================
# 修改 4: orchestrator/mod.rs - collapse_tool_calls
# =============================================================================
#
# 位置: notify_task 的 else 分支（约第 2981 行）
#
# 原始行为:
#   每收到工具调用通知 → 发送一条独立消息
#   结果: 消息列表刷屏
#
# 优化后行为:
#   1. 累积工具调用文本
#   2. 包裹在 <details><summary>Tool Calls</summary>...</details> 中
#   3. 有 draft_id → 更新 draft
#   4. 无 draft_id → 发送新 draft
#
# 为什么用 <details> 块:
# - HTML5 原生折叠元素，无需 JavaScript
# - Matrix 支持渲染 HTML
# - 用户可折叠/展开查看
#

TARGET_ORCH="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

cp "$TARGET_ORCH" "${TARGET_ORCH}.bak"

awk '
NR == 2981 {
    print "    } else {"
    print "        // TOOL CALLS COLLAPSE: accumulate tool calls in draft with <details> block"
    print "        Some(tokio::spawn(async move {"
    print "            let thread_ts = notify_thread_root;"
    print "            let mut tool_calls_draft_id: Option<String> = None;"
    print "            let mut accumulated_tool_calls = String::new();"
    print "            while let Some(text) = notify_rx.recv().await {"
    print "                if let Some(ref ch) = notify_channel {"
    print "                    if !accumulated_tool_calls.is_empty() {"
    print "                        accumulated_tool_calls.push_str(\"\\n\");"
    print "                    }"
    print "                    accumulated_tool_calls.push_str(&text);"
    print "                    let details_content = format!("
    print "                        \"<details><summary>Tool Calls</summary>\\n\\n{}\\n</details>\","
    print "                        accumulated_tool_calls"
    print "                    );"
    print "                    if let Some(ref draft_id) = tool_calls_draft_id {"
    print "                        let _ = ch.update_draft(&notify_reply_target, draft_id, &details_content).await;"
    print "                    } else {"
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
NR >= 2982 && NR <= 2995 { next }
{ print }
' "${TARGET_ORCH}.bak" > "$TARGET_ORCH"

rm -f "${TARGET_ORCH}.bak"

echo "Patch applied: zeroclaw_matrix_partial"
