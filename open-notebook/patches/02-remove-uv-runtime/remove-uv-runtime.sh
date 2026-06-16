#!/bin/bash
# Drop the uv binary from the runtime stage and bypass it in supervisord.
#
# The runtime stage already disables sync via `UV_NO_SYNC=1`, so uv only
# serves as a process launcher (`uv run --no-sync uvicorn ...`). The same
# entrypoints exist as plain executables under /app/.venv/bin, so we can
# delete the ~30 MB uv binary copy and call them directly.
#
# Files affected:
#   - Dockerfile
#   - Dockerfile.single
#   - supervisord.conf
#   - supervisord.single.conf  (if present)
#
# Usage: apply_patch 02-remove-uv-runtime <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

# --- 1. Dockerfile changes -------------------------------------------------

remove_runtime_uv_copy() {
    local dockerfile="$1"

    if [ ! -f "$dockerfile" ]; then
        return 0
    fi

    echo "Patching: $dockerfile"

    if ! grep -q "ghcr.io/astral-sh/uv:latest" "$dockerfile"; then
        echo "  No uv COPY found, skipping."
        return 0
    fi

    # Remove only the runtime-stage `COPY --from=ghcr.io/astral-sh/uv ...`.
    # The builder stage also has one — we keep it (uv still drives `uv sync`
    # during build). We identify the runtime occurrence as the *second*
    # match in the file.
    awk '
        BEGIN { seen = 0 }
        /^COPY --from=ghcr\.io\/astral-sh\/uv:latest/ {
            seen++
            if (seen >= 2) {
                # Drop this line plus the immediately preceding "Install uv ..."
                # comment block, if present (cosmetic).
                next
            }
        }
        { print }
    ' "$dockerfile" > "$dockerfile.tmp" && mv "$dockerfile.tmp" "$dockerfile"

    # Drop the now-orphaned `ENV UV_NO_SYNC=1` line; without uv on PATH it has
    # no effect, but keeping it would mislead readers.
    sed -i.bak '/^ENV UV_NO_SYNC=1$/d' "$dockerfile" && rm -f "$dockerfile.bak"
}

remove_runtime_uv_copy "$TARGET_DIR/Dockerfile"
remove_runtime_uv_copy "$TARGET_DIR/Dockerfile.single"

# --- 2. supervisord changes ------------------------------------------------

# Replace `uv run --no-sync <bin> ...` with `/app/.venv/bin/<bin> ...`.
patch_supervisord() {
    local conf="$1"

    if [ ! -f "$conf" ]; then
        return 0
    fi

    echo "Patching: $conf"

    # Replace both spellings used upstream:
    #   `uv run --no-sync <bin> ...`  (multi-container supervisord.conf)
    #   `uv run <bin> ...`            (single-container supervisord.single.conf)
    # with a direct call into the venv's installed entrypoint. The optional
    # `--no-sync` token is consumed by the regex in either case.
    sed -E -i.bak \
        -e 's|uv run( --no-sync)? uvicorn |/app/.venv/bin/uvicorn |' \
        -e 's|uv run( --no-sync)? surreal-commands-worker |/app/.venv/bin/surreal-commands-worker |' \
        "$conf"
    rm -f "$conf.bak"
}

patch_supervisord "$TARGET_DIR/supervisord.conf"
patch_supervisord "$TARGET_DIR/supervisord.single.conf"

echo "remove-uv-runtime patch applied"
