#!/bin/bash
# collapse_tool_calls: 工具调用使用 draft 消息更新，包裹在 <details> 块中

DESCRIPTION="\
修改 orchestrator/mod.rs:
1. 当 show_tool_calls=true 时，使用 draft 消息累积工具调用
2. 工具调用内容包裹在 <details><summary>Tool Calls</summary>...</details> 中
3. 追加到 draft 消息而不是发送独立消息"

TARGET="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

# 先备份
cp "$TARGET" "${TARGET}.bak"

# 使用 awk 进行多行替换，替换 2981-2995 行
awk '
NR == 2981 {
    print "    } else {"
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
NR >= 2982 && NR <= 2995 { next }
{ print }
' "${TARGET}.bak" > "$TARGET"

rm -f "${TARGET}.bak"