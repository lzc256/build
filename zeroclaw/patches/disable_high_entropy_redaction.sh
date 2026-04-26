#!/bin/bash
# =============================================================================
# disable_high_entropy_redaction.sh - 禁用 LeakDetector 高熵 token 审查
# =============================================================================

DESCRIPTION="禁用 LeakDetector 高熵 token 审查:
- LeakDetector 添加 skip_high_entropy 字段和 builder 方法
- scan() 中根据 skip_high_entropy 跳过 check_high_entropy_tokens
- SecurityConfig 添加 disable_high_entropy_redaction 配置项
- sanitize_channel_response 传入配置控制 LeakDetector 行为
- deliver_announcement 传入配置控制 cron 输出审查
- PR: https://github.com/zeroclaw-labs/zeroclaw/pull/5080"

set -e

# =============================================================================
# 1. leak_detector.rs
# =============================================================================

TARGET_LD="$1/crates/zeroclaw-runtime/src/security/leak_detector.rs"

echo "Patching leak_detector.rs..."

# 1a. Add skip_high_entropy field to struct
perl -i -0pe '
s{(    sensitivity: f64,\n)}{$1    skip_high_entropy: bool,\n};
' "$TARGET_LD"

if ! grep -q "skip_high_entropy: bool" "$TARGET_LD"; then
    echo "ERROR: Failed to add skip_high_entropy field"
    exit 1
fi
echo "  ✓ Added skip_high_entropy field"

# 1b. Init in new()
perl -i -pe 's/Self \{ sensitivity: 0\.7 \}/Self { sensitivity: 0.7, skip_high_entropy: false }/' "$TARGET_LD"

if ! grep -q "skip_high_entropy: false" "$TARGET_LD"; then
    echo "ERROR: Failed to init skip_high_entropy in new()"
    exit 1
fi
echo "  ✓ Init skip_high_entropy in new()"

# 1c. Init in with_sensitivity()
perl -i -pe '
if (/sensitivity: sensitivity\.clamp\(0\.0, 1\.0\),/ && !/skip_high_entropy/) {
    $_ .= "            skip_high_entropy: false,\n" if /^\s+\}$/;
}
' "$TARGET_LD"

# with_sensitivity has single-line closing brace; use multiline approach
perl -i -0pe '
s#(sensitivity: sensitivity\.clamp\(0\.0, 1\.0\),\n        \})#$1\n#;
s#sensitivity: sensitivity\.clamp\(0\.0, 1\.0\),\n        \}#sensitivity: sensitivity.clamp(0.0, 1.0),\n            skip_high_entropy: false,\n        }#;
' "$TARGET_LD"

COUNT=$(grep -c "skip_high_entropy: false" "$TARGET_LD")
if [ "$COUNT" -lt 2 ]; then
    echo "ERROR: Failed to init skip_high_entropy in with_sensitivity() (count=$COUNT)"
    exit 1
fi
echo "  ✓ Init skip_high_entropy in with_sensitivity()"

# 1d. Add with_high_entropy_disabled method after with_sensitivity
python3 -c "
target = '$TARGET_LD'
with open(target, 'r') as f:
    content = f.read()

method = '''
    /// Disable the high-entropy token heuristic.
    ///
    /// When set, scan skips Shannon-entropy-based detection
    /// while all pattern-based checks remain active.
    pub fn with_high_entropy_disabled(mut self, disabled: bool) -> Self {
        self.skip_high_entropy = disabled;
        self
    }
'''

# Find with_sensitivity closing brace and insert after it
# Pattern: skip_high_entropy: false,\n    }
# Note: the actual code may have extra whitespace/newlines
marker = 'skip_high_entropy: false,'
idx = content.find(marker)
if idx == -1:
    raise Exception('Could not find skip_high_entropy in with_sensitivity')

# Find the closing brace of the Self { ... } block
# Search forward from marker to find the pattern
search_start = idx
search_end = idx + 200  # Look within reasonable distance
search_region = content[search_start:search_end]

# Find the position after skip_high_entropy: false,
# Then find the closing } for the struct literal
close_brace_pos = search_region.find('}')
if close_brace_pos == -1:
    raise Exception('Could not find closing brace')

# Calculate absolute position
insert_pos = search_start + close_brace_pos + 1

content = content[:insert_pos] + method + content[insert_pos:]

with open(target, 'w') as f:
    f.write(content)
"

if ! grep -q "with_high_entropy_disabled" "$TARGET_LD"; then
    echo "ERROR: Failed to add with_high_entropy_disabled method"
    exit 1
fi
echo "  ✓ Added with_high_entropy_disabled method"

# 1e. Conditional skip in scan()
perl -i -pe '
s#self\.check_high_entropy_tokens\(content, &mut patterns, &mut redacted\);#if !self.skip_high_entropy {
            self.check_high_entropy_tokens(content, &mut patterns, &mut redacted);
        }#;
' "$TARGET_LD"

if ! grep -q "if !self.skip_high_entropy" "$TARGET_LD"; then
    echo "ERROR: Failed to add conditional skip in scan()"
    exit 1
fi
echo "  ✓ Added conditional skip in scan()"

# 2. schema.rs - SecurityConfig
TARGET_SCHEMA="$1/crates/zeroclaw-config/src/schema.rs"

echo "Patching schema.rs..."

# Find the closing brace of SecurityConfig and add new field before it
perl -i -pe '
if (/pub webauthn: WebAuthnConfig,/) {
    $_ .= "    /// Disable the high-entropy token redaction heuristic in the leak detector.\n    ///\n    /// When `true`, the LeakDetector skips Shannon-entropy-based token\n    /// flagging while all pattern-based checks (API keys, AWS credentials,\n    /// private keys, JWTs, database URLs, generic secrets) remain active.\n    /// Useful when outbound content regularly contains legitimate high-entropy\n    /// strings such as base64-encoded payloads or API usage examples.\n    #[serde(default)]\n    pub disable_high_entropy_redaction: bool,\n";
}
' "$TARGET_SCHEMA"

if ! grep -q "disable_high_entropy_redaction" "$TARGET_SCHEMA"; then
    echo "ERROR: Failed to add disable_high_entropy_redaction to SecurityConfig"
    exit 1
fi
echo "  ✓ Added disable_high_entropy_redaction to SecurityConfig"

# =============================================================================
# 3. orchestrator/mod.rs - sanitize_channel_response
# =============================================================================

TARGET_ORCH="$1/crates/zeroclaw-channels/src/orchestrator/mod.rs"

echo "Patching orchestrator/mod.rs..."

# 3a. Add parameter
python3 -c "
import sys
target = '$TARGET_ORCH'
with open(target, 'r') as f:
    content = f.read()
old = 'fn sanitize_channel_response(response: &str, tools: &[Box<dyn Tool>]) -> String'
new = 'fn sanitize_channel_response(response: &str, tools: &[Box<dyn Tool>], disable_high_entropy_redaction: bool) -> String'
content = content.replace(old, new)
with open(target, 'w') as f:
    f.write(content)
"

if ! grep -q "disable_high_entropy_redaction: bool" "$TARGET_ORCH"; then
    echo "ERROR: Failed to add parameter to sanitize_channel_response"
    exit 1
fi
echo "  ✓ Added parameter to sanitize_channel_response"

# 3b. Wire in LeakDetector call
python3 -c "
target = '$TARGET_ORCH'
with open(target, 'r') as f:
    content = f.read()
content = content.replace('LeakDetector::new().scan(', 'LeakDetector::new().with_high_entropy_disabled(disable_high_entropy_redaction).scan(')
with open(target, 'w') as f:
    f.write(content)
"

if ! grep -q "with_high_entropy_disabled.*disable_high_entropy_redaction" "$TARGET_ORCH"; then
    echo "ERROR: Failed to wire with_high_entropy_disabled in sanitize_channel_response"
    exit 1
fi
echo "  ✓ Wired with_high_entropy_disabled in sanitize_channel_response"

# 3c. Pass config at call site
python3 -c "
target = '$TARGET_ORCH'
with open(target, 'r') as f:
    content = f.read()
content = content.replace('sanitize_channel_response(&outbound_response, ctx.tools_registry.as_ref())', 'sanitize_channel_response(&outbound_response, ctx.tools_registry.as_ref(), ctx.prompt_config.security.disable_high_entropy_redaction)')
with open(target, 'w') as f:
    f.write(content)
"

if ! grep -q "sanitize_channel_response.*disable_high_entropy_redaction" "$TARGET_ORCH"; then
    echo "ERROR: Failed to pass config to sanitize_channel_response call"
    exit 1
fi
echo "  ✓ Passed config to sanitize_channel_response call"

# 3d. Wire in deliver_announcement
python3 -c "
target = '$TARGET_ORCH'
with open(target, 'r') as f:
    content = f.read()
content = content.replace('let leak_detector = zeroclaw_runtime::security::LeakDetector::new()', 'let leak_detector = zeroclaw_runtime::security::LeakDetector::new().with_high_entropy_disabled(config.security.disable_high_entropy_redaction)')
with open(target, 'w') as f:
    f.write(content)
"

if grep -q "LeakDetector::new().with_high_entropy_disabled" "$TARGET_ORCH"; then
    echo "  ✓ Wired with_high_entropy_disabled in deliver_announcement"
fi

# 3e. Fix test calls - add , false parameter
# The function now takes 3 args, tests call with 2 - need to add false as 3rd
python3 -c "
import re
target = '$TARGET_ORCH'
with open(target, 'r') as f:
    content = f.read()

# Find all test calls to sanitize_channel_response that only have 2 args
# Pattern: sanitize_channel_response(arg1, arg2);  or  sanitize_channel_response(arg1, &arg2);
# We need to add false as third arg

# Match function call at end of line with );
content = re.sub(
    r'(sanitize_channel_response\([^,]+,\s*[^)]+)\)(\s*);',
    r'\1, false)\2;',
    content,
    flags=re.MULTILINE
)

with open(target, 'w') as f:
    f.write(content)
"

echo "  ✓ Fixed test calls to sanitize_channel_response"

echo "  ✓ Fixed test calls to sanitize_channel_response"

echo ""
echo "========================================="
echo "Patch applied successfully!"
echo "========================================="
