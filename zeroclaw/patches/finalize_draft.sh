#!/bin/bash
# finalize_draft: 在 Partial 模式下删除 draft 并发送最终消息

DESCRIPTION="\
修改 matrix.rs:
1. 添加 partial_thread_ts 字段追踪线程上下文
2. send_draft: Partial 模式保存 thread_ts
3. finalize_draft: Partial 模式删除 draft 并在新线程中发送最终消息"

TARGET="$1/crates/zeroclaw-channels/src/matrix.rs"

# 使用 perl 进行所有替换
perl -i -0pe '
# 1. 添加 partial_thread_ts 字段
s/(multi_message_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,)\n/$1\n    \/\/ Thread context captured from `send_draft()` for Partial mode final message.\n    partial_thread_ts: Arc<Mutex<HashMap<String, Option<String>>>>,\n/g;

# 2. 在 send_draft 的 MultiMessage 分支中添加 thread_ts 保存
s/(self\.multi_message_sent_len\.lock\(\)\.await\.clear\(\);)\n/$1\n                \/\/ Save thread context for Partial mode final message.\n                self.partial_thread_ts.lock().await.insert(room_id.clone(), message.thread_ts.clone());\n/g;

# 3. 修改 finalize_draft 中 Partial 模式
s/StreamMode::Partial => \{\n\s+\/\/ Final m\.replace edit with complete text\.\n\s+self\.last_draft_edit\.lock\(\)\.await\.remove\(&room_id\);\n\s+self\.edit_message\(&room_id, message_id, text\)\.await\n\s+\}/StreamMode::Partial => {\n                \/\/ Delete draft and send final message in original thread.\n                self.last_draft_edit.lock().await.remove(\&room_id);\n                let thread_ts = self.partial_thread_ts.lock().await.remove(\&room_id);\n                if let Err(e) = self.redact_message(\&room_id, message_id, None).await {\n                    tracing::debug!("Matrix draft redaction failed: {e}");\n                }\n                let mut msg = SendMessage::new(text, recipient);\n                msg.thread_ts = thread_ts;\n                if let Err(e) = self.send(\&msg).await {\n                    tracing::debug!("Matrix final message send failed: {e}");\n                }\n                Ok(())\n            }/g;
' "$TARGET"
