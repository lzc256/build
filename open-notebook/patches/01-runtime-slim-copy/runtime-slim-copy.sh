#!/bin/bash
# Replace runtime stage `COPY . /app` with whitelist-based copies.
#
# Upstream Dockerfile / Dockerfile.single both do `COPY . /app` in the runtime
# stage, which drags in tests/, examples/, frontend/ source, CHANGELOG, dev
# docs, and (via the build context) any local node_modules / .next that got
# generated in-place. Only a small set of paths are actually needed at run
# time. This patch swaps the wildcard copy for a minimal whitelist.
#
# Files affected (whichever exist):
#   - Dockerfile
#   - Dockerfile.single
#
# Usage: apply_patch 01-runtime-slim-copy <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

patch_dockerfile() {
    local dockerfile="$1"

    if [ ! -f "$dockerfile" ]; then
        return 0
    fi

    echo "Patching: $dockerfile"

    if grep -q "Slimmed runtime copy (whitelist)" "$dockerfile"; then
        echo "  Already slimmed, skipping."
        return 0
    fi

    # Replace `COPY . /app` and `COPY . /app/` with a whitelist block. Inline
    # awk (no `-v` multi-line variable) for BSD-awk compatibility on macOS.
    # The whitelist matches the import surface of api.main, supervisord.conf,
    # scripts/wait-for-api.sh, and run_api.py.
    awk '
        $0 == "COPY . /app" || $0 == "COPY . /app/" {
            print "# --- Slimmed runtime copy (whitelist) -----------------------------------"
            print "# Only ship what the API / worker / startup scripts actually need."
            print "# Adding a new top-level module to runtime requires extending this list."
            print "COPY open_notebook /app/open_notebook"
            print "COPY api /app/api"
            print "COPY commands /app/commands"
            print "COPY prompts /app/prompts"
            print "COPY scripts /app/scripts"
            print "COPY run_api.py /app/run_api.py"
            print "COPY pyproject.toml uv.lock /app/"
            print "# ------------------------------------------------------------------------"
            next
        }
        { print }
    ' "$dockerfile" > "$dockerfile.tmp" && mv "$dockerfile.tmp" "$dockerfile"

    if ! grep -q "Slimmed runtime copy (whitelist)" "$dockerfile"; then
        echo "  Warning: no \`COPY . /app\` line found in $dockerfile" >&2
    fi
}

patch_dockerfile "$TARGET_DIR/Dockerfile"
patch_dockerfile "$TARGET_DIR/Dockerfile.single"

echo "runtime-slim-copy patch applied"
