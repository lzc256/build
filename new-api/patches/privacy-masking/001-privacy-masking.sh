#!/bin/bash
# Server-side prompt masking for new-api, using magpie's rule engine.
#
# Nothing from magpie is stored in this repository. The script fetches the
# magpie source at build time, copies only the production files of its rule
# engine into the target tree, adds a small glue package, and inserts a
# single middleware hook into new-api's relay router.
#
# Env:
#   MAGPIE_REPO  - git URL (default https://github.com/yetone/magpie.git)
#   MAGPIE_REF   - branch/tag/commit (default main)
#   MAGPIE_DIR   - local cache dir (default <build>/.upstream-repos/magpie-src)
# The masking is always on for relay routes; there is no setting, no DB row
# and no frontend change.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <new-api-source-dir>" >&2
    exit 1
fi

TARGET="$(cd "$1" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

MAGPIE_REPO="${MAGPIE_REPO:-https://github.com/yetone/magpie.git}"
MAGPIE_REF="${MAGPIE_REF:-main}"
MAGPIE_DIR="${MAGPIE_DIR:-$BUILD_DIR/.upstream-repos/magpie-src}"

echo "========================================="
echo "Patch: privacy-masking (magpie rule engine)"
echo "Target: $TARGET"
echo "Magpie: $MAGPIE_REPO @ $MAGPIE_REF"
echo "========================================="

# ---------------------------------------------------------------- fetch ---
mkdir -p "$(dirname "$MAGPIE_DIR")"
if [ -d "$MAGPIE_DIR/.git" ]; then
    echo "Fetching magpie..."
else
    echo "Cloning magpie..."
    git clone --no-checkout --depth 1 "$MAGPIE_REPO" "$MAGPIE_DIR"
fi
git -C "$MAGPIE_DIR" fetch --depth 1 origin "$MAGPIE_REF"
git -C "$MAGPIE_DIR" checkout -q --detach "$(git -C "$MAGPIE_DIR" rev-parse FETCH_HEAD)"
MAGPIE_COMMIT="$(git -C "$MAGPIE_DIR" rev-parse HEAD)"
echo "Magpie commit: $MAGPIE_COMMIT"

# ------------------------------------------------------------ copy code ---
REDACT_DST="$TARGET/internal/privacy/redact"
LAZYRE_DST="$TARGET/internal/privacy/lazyre"
mkdir -p "$REDACT_DST" "$LAZYRE_DST"

# Production files only: magpie's redact tests pull in optional model/pii
# packages we deliberately do not build.
for f in "$MAGPIE_DIR"/internal/redact/*.go; do
    case "$(basename "$f")" in
        *_test.go) continue ;;
    esac
    cp "$f" "$REDACT_DST/"
done
cp "$MAGPIE_DIR/internal/redact/bip39english.txt" "$REDACT_DST/"
cp "$MAGPIE_DIR/internal/redact/zhdict.txt" "$REDACT_DST/"
cp "$MAGPIE_DIR/LICENSE" "$REDACT_DST/LICENSE"
cp "$MAGPIE_DIR/internal/lazyre/lazyre.go" "$LAZYRE_DST/"

# Rewrite magpie's internal import to its new location under new-api.
find "$TARGET/internal/privacy" -type f -name '*.go' -print0 | \
    xargs -0 perl -pi -e \
    's{github\.com/yetone/magpie/internal/lazyre}{github.com/QuantumNous/new-api/internal/privacy/lazyre}g'

# --------------------------------------------------------------- glue -----
mkdir -p "$TARGET/privacy"

cat > "$TARGET/privacy/middleware.go" <<'EOF'
package privacy

import (
	"bytes"
	"io"
	"strings"

	"github.com/QuantumNous/new-api/common"
	"github.com/QuantumNous/new-api/internal/privacy/redact"
	"github.com/gin-gonic/gin"
)

// Middleware masks every JSON relay request before it reaches the channel
// adapters, and restores placeholders in the response, streaming included.
// It is always on for relay routes: no setting, no database, no frontend.
func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isRelayPath(c.Request.URL.Path) || strings.EqualFold(c.GetHeader("Upgrade"), "websocket") {
			c.Next()
			return
		}

		maskRequestBody(c)

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

// maskRequestBody replaces the request body with its masked version. The
// body storage cache is invalidated so new-api's reusable unmarshalling
// reads the masked bytes.
func maskRequestBody(c *gin.Context) {
	if !strings.Contains(c.ContentType(), "application/json") {
		return
	}
	storage, err := common.GetBodyStorage(c)
	if err != nil {
		return
	}
	body, err := storage.Bytes()
	if err != nil || len(body) == 0 {
		return
	}

	masked, _ := redact.MaskJSON(body, redact.Options{
		Secrets:  true,
		Personal: true,
	})
	if bytes.Equal(masked, body) {
		return
	}

	_ = storage.Close()
	c.Request.Body = io.NopCloser(bytes.NewReader(masked))
	c.Request.ContentLength = int64(len(masked))
	c.Set(common.KeyBodyStorage, nil)
	c.Set(common.KeyRequestBody, nil)
}
EOF

cat > "$TARGET/privacy/gin_writer.go" <<'EOF'
package privacy

import (
	"net/http"

	"github.com/QuantumNous/new-api/internal/privacy/redact"
	"github.com/gin-gonic/gin"
)

// ginWriter makes magpie's http.ResponseWriter wrapper usable as gin's
// richer ResponseWriter. All data methods go through the redact writer so
// restored values reach the client; metadata methods stay with gin.
type ginWriter struct {
	gin.ResponseWriter
	rw *redact.Writer
}

func (w *ginWriter) Header() http.Header { return w.rw.Header() }

func (w *ginWriter) Write(p []byte) (int, error) { return w.rw.Write(p) }

func (w *ginWriter) WriteString(s string) (int, error) { return w.Write([]byte(s)) }

func (w *ginWriter) WriteHeader(code int) { w.rw.WriteHeader(code) }

// WriteHeaderNow is called by gin right before writing. Delegate to the
// redact writer so it can drop Content-Length before the header is frozen.
func (w *ginWriter) WriteHeaderNow() { w.rw.WriteHeader(w.ResponseWriter.Status()) }

func (w *ginWriter) Flush() { w.rw.Flush() }
EOF

cat > "$TARGET/privacy/integration_test.go" <<'EOF'
package privacy

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/QuantumNous/new-api/common"
	"github.com/gin-gonic/gin"
)

var testSecret = "alice" + "@" + "acme" + ".com"
var testEmail = "bob" + "@" + "acme" + ".com"

func TestMiddlewareMasksRequestAndRestoresResponse(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var seenByHandler string
	r := gin.New()
	r.Use(Middleware())
	r.POST("/v1/test", func(c *gin.Context) {
		storage, err := common.GetBodyStorage(c)
		if err != nil {
			t.Fatal(err)
		}
		b, err := storage.Bytes()
		if err != nil {
			t.Fatal(err)
		}
		seenByHandler = string(b)
		c.Data(http.StatusOK, "text/plain; charset=utf-8", b)
	})

	body, _ := json.Marshal(map[string]string{
		"prompt": "use " + testSecret + " and mail " + testEmail,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/test", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if strings.Contains(seenByHandler, testSecret) || strings.Contains(seenByHandler, testEmail) {
		t.Fatalf("handler saw plaintext: %s", seenByHandler)
	}
	resp := w.Body.String()
	if !strings.Contains(resp, testSecret) || !strings.Contains(resp, testEmail) {
		t.Fatalf("response not restored: %s", resp)
	}
}
EOF
cat > "$TARGET/privacy/NOTICE" <<EOF

This build includes the rule engine from github.com/yetone/magpie
(commit $MAGPIE_COMMIT), licensed under the MIT License.
The full license text is at internal/privacy/redact/LICENSE.
No magpie source is stored in this repository; it is fetched at build time.
EOF

# --------------------------------------------------------------- hook -----
ROUTER="$TARGET/router/relay-router.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$ROUTER"; then
    perl -0pi -e 's#(\t"github\.com/QuantumNous/new-api/middleware"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$ROUTER"
fi
if ! grep -q 'privacy.Middleware()' "$ROUTER"; then
    perl -0pi -e 's#(\trouter\.Use\(middleware\.DecompressRequestMiddleware\(\)\)\n)#$1\trouter.Use(privacy.Middleware())\n#' "$ROUTER"
fi

grep -q '"github.com/QuantumNous/new-api/privacy"' "$ROUTER" || { echo "failed to add privacy import" >&2; exit 1; }
grep -q 'router.Use(privacy.Middleware())' "$ROUTER" || { echo "failed to add privacy hook" >&2; exit 1; }

echo "Applied privacy-masking hook to router/relay-router.go"
echo "========================================="
