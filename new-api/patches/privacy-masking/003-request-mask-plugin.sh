#!/bin/bash
# Adds a builtin request plugin "request-mask" whose JS hook is only glue:
# the actual masking is done by the magpie Go engine from 001/002.
# Response restoration stays in privacy.Middleware() at the HTTP writer layer.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <new-api-source-dir>" >&2
    exit 1
fi

TARGET="$(cd "$1" && pwd)"

echo "========================================="
echo "Patch: privacy-masking request plugin"
echo "Target: $TARGET"
echo "========================================="

for required in "$TARGET/privacy/insights.go" "$TARGET/internal/privacy/redact/redact.go"; do
    if [ ! -f "$required" ]; then
        echo "Missing $required; run 001 and 002 first" >&2
        exit 1
    fi
done

# ----------------------------------------------------- Go host function ----
cat > "$TARGET/privacy/plugin.go" <<'PPLUG'
package privacy

import (
	"encoding/json"
	"fmt"

	"github.com/QuantumNous/new-api/internal/privacy/redact"
)

type pluginMaskOptions struct {
	Secrets  *bool  `json:"secrets"`
	Personal *bool  `json:"personal"`
	Path     string `json:"path"`
	Model    string `json:"model"`
	UserID   string `json:"user_id"`
}

// MaskJSONForJS is the host function exposed to the builtin request-mask
// plugin. The JS plugin only passes the body and request metadata; magpie does
// the detection and our insight store records the hits.
func MaskJSONForJS(body []byte, metaJSON string) (string, error) {
	opts := redact.Options{Secrets: true, Personal: true}
	var meta pluginMaskOptions
	if metaJSON != "" {
		if err := json.Unmarshal([]byte(metaJSON), &meta); err != nil {
			return "", fmt.Errorf("invalid request-mask metadata: %w", err)
		}
	}
	if meta.Secrets != nil {
		opts.Secrets = *meta.Secrets
	}
	if meta.Personal != nil {
		opts.Personal = *meta.Personal
	}

	base := MaskEvent{RequestID: nextRequestID(), Path: meta.Path, Model: meta.Model, UserID: meta.UserID}
	opts.Seen = func(h redact.Hit) {
		e := base
		e.Kind = h.Kind
		e.By = h.By
		e.Action = h.Action
		e.Placeholder = h.Placeholder
		e.Head = h.Head
		e.Len = h.Len
		insights.record(e)
	}

	masked, _ := redact.MaskJSON(body, opts)
	return string(masked), nil
}
PPLUG

UTILS="$TARGET/pkg/jsplugin/utils.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$UTILS"; then
    perl -0pi -e 's#(\t"github\.com/MoeForge/moejs"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$UTILS"
fi
if ! grep -q 'magpieMaskJSON' "$UTILS"; then
    perl -0pi -e 's#(\t\t"hasCapability": runtime\.Function\("hasCapability", 1, func\(r \*moejs\.Realm, _ moejs\.Value, args \[\]moejs\.Value\) \(moejs\.Value, error\) \{\n\t\t\tname, err := stringValue\(r, moejs\.Arg\(args, 0\)\)\n\t\t\tif err != nil \{\n\t\t\t\treturn moejs\.Undefined\(\), err\n\t\t\t\}\n\t\t\treturn moejs\.Bool\(HasCapability\(name\)\), nil\n\t\t\}\),\n)#$1\t\t"magpieMaskJSON": runtime.Function("magpieMaskJSON", 2, func(r *moejs.Realm, _ moejs.Value, args []moejs.Value) (moejs.Value, error) {\n\t\t\tbody, err := stringValue(r, moejs.Arg(args, 0))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskJSON body must be a string")\n\t\t\t}\n\t\t\tmeta, err := stringValue(r, moejs.Arg(args, 1))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskJSON metadata must be a string")\n\t\t\t}\n\t\t\tmasked, err := privacy.MaskJSONForJS([]byte(body), meta)\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), err\n\t\t\t}\n\t\t\treturn moejs.String(masked), nil\n\t\t}),\n#' "$UTILS"
fi
grep -q 'magpieMaskJSON' "$UTILS" || { echo "failed to inject magpieMaskJSON" >&2; exit 1; }

# --------------------------------------------------- response-only hook ----
cat > "$TARGET/privacy/middleware.go" <<'PMW'
package privacy

import (
	"strings"

	"github.com/QuantumNous/new-api/internal/privacy/redact"
	"github.com/gin-gonic/gin"
)

// Middleware restores magpie placeholders in responses. Request masking is
// performed by the builtin request-mask plugin through the Go host function,
// so enabling/disabling the plugin controls masking while restoration remains
// a harmless no-op when no placeholders were produced.
func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isRelayPath(c.Request.URL.Path) || strings.EqualFold(c.GetHeader("Upgrade"), "websocket") {
			c.Next()
			return
		}

		original := c.Writer
		rw := redact.NewWriter(original)
		c.Writer = &ginWriter{ResponseWriter: original, rw: rw}
		defer rw.Finish()

		c.Next()
	}
}

func isRelayPath(path string) bool {
	return path == "/v1" || path == "/v1beta" ||
		strings.HasPrefix(path, "/v1/") || strings.HasPrefix(path, "/v1beta/")
}
PMW

cat > "$TARGET/privacy/integration_test.go" <<'PTEST'
package privacy

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestMaskJSONForJSUsesMagpieAndRecordsMetadata(t *testing.T) {
	plaintext := "alice" + "@" + "acme" + ".com"
	body, _ := json.Marshal(map[string]string{"prompt": "contact " + plaintext})
	meta, _ := json.Marshal(map[string]any{"secrets": true, "personal": true, "path": "/v1/chat/completions"})

	masked, err := MaskJSONForJS(body, string(meta))
	if err != nil {
		t.Fatal(err)
	}
	if masked == string(body) || strings.Contains(masked, plaintext) {
		t.Fatalf("body was not masked: %s", masked)
	}
	events, err := insights.events(1, "EMAIL", 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) == 0 {
		t.Fatal("no EMAIL insight recorded")
	}
	if strings.Contains(events[0].Placeholder, plaintext) {
		t.Fatal("insight contains plaintext")
	}
}
PTEST

# -------------------------------------------------- builtin plugin files ----
PLUGIN_DIR="$TARGET/plugins/tasks/request-mask"
mkdir -p "$PLUGIN_DIR"
cat > "$PLUGIN_DIR/plugin.js" <<'PJS'
export const meta = {
  apiVersion: 1,
  key: "request-mask",
  name: { en: "Request mask (Magpie)", zh: "请求脱敏（Magpie）" },
  description: {
    en: "Replaces secrets and personal data with magpie placeholders before sending; replies are restored automatically.",
    zh: "发送前使用 magpie 规则把密钥和个人信息替换为占位符，回复自动还原。",
  },
  version: "1.0.1",
  author: { name: "lzc256" },
  configSchema: {
    type: "object",
    properties: {
      secrets: {
        type: "boolean",
        title: { en: "Mask secrets", zh: "脱敏密钥" },
        description: { en: "API keys, tokens, private keys and passwords", zh: "API 密钥、令牌、私钥和密码" },
        default: true,
      },
      personal: {
        type: "boolean",
        title: { en: "Mask personal data", zh: "脱敏个人信息" },
        description: { en: "Emails, phone numbers, ID and bank card numbers", zh: "邮箱、手机号、身份证号和银行卡号" },
        default: true,
      },
    },
  },
  samples: [
    {
      name: { en: "Email and API key", zh: "邮箱和 API 密钥" },
      lang: "en",
      format: "openai",
      body: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "user",
            content: "Send the report to [REDACTED] using sk-abcdefghijklmnopqrstuv.",
          },
        ],
      },
    },
  ],
};

function requestMeta(ctx) {
  return JSON.stringify({
    secrets: (ctx.config || {}).secrets !== false,
    personal: (ctx.config || {}).personal !== false,
    path: ctx.path || "",
    model: ctx.model || "",
    user_id: ctx.user && ctx.user.id ? String(ctx.user.id) : "",
  });
}

function mask(ctx, req) {
  const original = JSON.stringify(req.body);
  const masked = utils.magpieMaskJSON(original, requestMeta(ctx));
  if (!masked || masked === original) return { action: "continue" };
  return {
    action: "continue",
    effects: [{ type: "json.patch", ops: [{ op: "replace", path: "", value: JSON.parse(masked) }] }],
  };
}

export function ingress(ctx, req) { return mask(ctx, req); }
export function egress(ctx, req) { return mask(ctx, req); }
export function reply() { return { action: "pass" }; }
PJS

if [ -f "$TARGET/plugins/tasks/request-redact/icon.svg" ]; then
    cp "$TARGET/plugins/tasks/request-redact/icon.svg" "$PLUGIN_DIR/icon.svg"
else
    cat > "$PLUGIN_DIR/icon.svg" <<'PSVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#8b5cf6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 4 6v5c0 5 3.4 8.7 8 10 4.6-1.3 8-5 8-10V6l-8-3Z"/><path d="M9 12h6"/></svg>
PSVG
fi

# The upstream test hardcodes the builtin request-plugin list.
TEST_FILE="$TARGET/plugins/builtin_plugins_test.go"
if [ -f "$TEST_FILE" ] && ! grep -q '"request-mask"' "$TEST_FILE"; then
    perl -0pi -e 's#(	"request-redact":     \{"ingress", "egress", "reply"\},\n)#$1\t"request-mask":      {"ingress", "egress", "reply"},\n#' "$TEST_FILE"
fi

echo "Applied privacy-masking request plugin"
echo "========================================="
