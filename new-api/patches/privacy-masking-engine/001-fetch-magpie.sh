#!/bin/bash
# Fetches magpie at build time and copies its rule engine into the target.
# This cannot be a .patch: the source is intentionally not stored in this repo.

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
echo "Patch: privacy-masking engine (magpie)"
echo "Target: $TARGET"
echo "Magpie: $MAGPIE_REPO @ $MAGPIE_REF"
echo "========================================="

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

REDACT_DST="$TARGET/internal/privacy/redact"
LAZYRE_DST="$TARGET/internal/privacy/lazyre"
GUARD_DST="$TARGET/internal/privacy/guard"
mkdir -p "$REDACT_DST" "$LAZYRE_DST" "$GUARD_DST/coreml"

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

# AstrLink Guard is a pure-Go int8 ONNX classifier. Copy only its inference
# package and embedded CoreML layout; the model files themselves are marked
# below and downloaded at runtime by new-api.
for f in "$MAGPIE_DIR"/internal/pii/guard/*.go "$MAGPIE_DIR"/internal/pii/guard/*.s; do
    case "$(basename "$f")" in
        *_test.go) continue ;;
    esac
    cp "$f" "$GUARD_DST/"
done
cp "$MAGPIE_DIR/internal/pii/guard/coreml.json" "$GUARD_DST/"
cp "$MAGPIE_DIR/internal/pii/guard/coreml.mlmodel" "$GUARD_DST/"
for f in "$MAGPIE_DIR"/internal/pii/guard/coreml/*.go; do
    case "$(basename "$f")" in
        *_test.go) continue ;;
    esac
    cp "$f" "$GUARD_DST/coreml/"
done

# Rewrite magpie's internal import to its new location under new-api.
find "$TARGET/internal/privacy" -type f -name '*.go' -print0 | \
    xargs -0 perl -pi -e \
    's{github\.com/yetone/magpie/internal/lazyre}{github.com/QuantumNous/new-api/internal/privacy/lazyre}g'
perl -pi -e \
    's{github\.com/yetone/magpie/internal/pii/guard/coreml}{github.com/QuantumNous/new-api/internal/privacy/guard/coreml}g' \
    "$GUARD_DST"/*.go

# NOTICE is generated because the commit comes from MAGPIE_REF at build time.
mkdir -p "$TARGET/privacy"
cat > "$TARGET/privacy/NOTICE" <<EOF

This build includes the rule engine and the AstrLink Guard inference code
from github.com/yetone/magpie (commit $MAGPIE_COMMIT), licensed under the
MIT License. The full license text is at internal/privacy/redact/LICENSE.
No magpie source is stored in this repository; it is fetched at build time.

AstrLink Guard model files (Apache-2.0) are downloaded at runtime from
https://huggingface.co/QuantumNous/astrlink-guard and are not part of this
repository or the container image until downloaded. See the model card for
the model's license and terms.
EOF

echo "Applied privacy-masking engine"
echo "========================================="
