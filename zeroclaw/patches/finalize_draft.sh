#!/bin/bash
# finalize_draft: 在 Partial 模式下删除 draft 并发送最终消息

DESCRIPTION="\
修改 matrix.rs:
1. 添加 partial_thread_ts 字段追踪线程上下文
2. 构造函数中初始化 partial_thread_ts
3. send_draft Partial 分支: 保存 thread_ts
4. finalize_draft Partial 分支: 删除 draft 并发送最终消息"

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

# 使用 perl 进行精确替换
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
# 修改 insert 使用 room_id.clone()，并在之后保存 thread_ts
s{(\.insert\(room_id, std::time::Instant::now\(\)\);)\n\n(\s+)Ok\(Some\(event_id\)\)}
{.insert(room_id.clone(), std::time::Instant::now());

$2// Save thread context for Partial mode final message.
                self.partial_thread_ts.lock().await.insert(room_id, message.thread_ts.clone());

                Ok(Some(event_id))};

# 4. 修改 finalize_draft 中 Partial 分支的实现
s{StreamMode::Partial => \{\n\s+// Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}}
{StreamMode::Partial => {
                // Delete draft and send final message in original thread.
                self.last_draft_edit.lock().await.remove(\&room_id);
                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id).flatten();
                if let Err(e) = self.redact_message(\&room_id, message_id, None).await {
                    tracing::debug!("Matrix draft redaction failed: {e}");
                }
                let mut msg = SendMessage::new(text, recipient);
                msg.thread_ts = thread_ts;
                if let Err(e) = self.send(\&msg).await {
                    tracing::debug!("Matrix final message send failed: {e}");
                }
                Ok(())
            }};
' "$TARGET"