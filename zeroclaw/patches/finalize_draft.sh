#!/bin/bash
# finalize_draft: 在 Partial 模式下更新 draft 为 Done 并发送最终消息

DESCRIPTION="\
修改 matrix.rs:
1. 添加 partial_thread_ts 字段追踪线程上下文
2. 构造函数中初始化 partial_thread_ts
3. send_draft Partial 分支: 保存 thread_ts
4. finalize_draft Partial 分支: 更新 draft 为 Done! 并发送最终消息（不删除 draft）"

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

perl -i -0pe '
# 1. 在 multi_message_thread_ts 字段后添加 partial_thread_ts 字段
s{(multi_message_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,)}
{$1
    /// Thread context captured from send_draft for Partial mode final message.
    partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,};

# 2. 在构造函数中初始化 partial_thread_ts
s{(multi_message_thread_ts: Arc::new\(Mutex::new\(HashMap::new\(\)\)\),)}
{$1
            partial_thread_ts: Arc::new(Mutex::new(HashMap::new())),};

# 3. 在 send_draft 的 Partial 分支中保存 thread_ts
s{(\.insert\(room_id, std::time::Instant::now\(\)\);)\n\n(\s+)Ok\(Some\(event_id\)\)}
{.insert(room_id.clone(), std::time::Instant::now());

$2// Save thread context for Partial mode final message.
                self.partial_thread_ts.lock().await.insert(room_id, message.thread_ts.clone());

                Ok(Some(event_id))};

# 4. 修改 finalize_draft 中 Partial 分支：更新 draft 为 Done! 并发送最终消息
s{StreamMode::Partial => \{\n\s+// Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}}
{StreamMode::Partial => {
                // Update draft to Done and send final message.
                self.last_draft_edit.lock().await.remove(\&room_id);
                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id).flatten();
                
                // Update draft with Done marker
                let done_content = "**Done!**";
                if let Err(e) = self.edit_message(\&room_id, message_id, done_content).await {
                    tracing::debug!("Matrix draft Done update failed: {e}");
                }
                
                // Send final message in thread
                let mut msg = SendMessage::new(text, recipient);
                msg.thread_ts = thread_ts;
                if let Err(e) = self.send(\&msg).await {
                    tracing::debug!("Matrix final message send failed: {e}");
                }
                Ok(())
            }};
' "$TARGET"