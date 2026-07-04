#!/bin/bash
# Patch Dockerfile for minimal hermes-agent build
# Usage: apply_patch dockerfile-patch <target_dir>
#
# Modifications:
# 1. Base image: debian:13.4 -> debian:13.4-slim
# 2. Remove build packages from apt-get (will reinstall temporarily in uv sync RUN)
# 3. Remove openssh-client docker-cli
# 4. Remove web/ui-tui COPY statements and frontend build
# 5. Reduce uv extras (keep matrix)
# 6. Add extra packages:
#    - requests dashscope gradio-client (general utilities)
#    - aiohttp==3.13.4 qrcode==7.4.2 (weixin/personal WeChat gateway: HTTP client + scan-login QR rendering)
#    - defusedxml==0.7.1 (wecom callback gateway: safe XML parsing for untrusted WeCom POST bodies)
#    These are pinned to match upstream pyproject.toml's [messaging] / [wecom] extras.
# 7. Single RUN for uv sync: install build deps, sync, remove build deps

set -e

DOCKERFILE="$1/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

echo "Patching Dockerfile: $DOCKERFILE"

# 1. Base image: debian:13.4 -> debian:13.4-slim
sed -i 's|^FROM debian:13\.4$|FROM debian:13.4-slim|' "$DOCKERFILE"

# 2. Remove build packages from initial apt-get
sed -i 's/ gcc g++ make cmake//' "$DOCKERFILE"

# 3. Remove openssh-client docker-cli
sed -i 's/ openssh-client docker-cli//' "$DOCKERFILE"

# 4. Remove web/ui-tui package.json COPY lines
sed -i '\|^COPY web/package\.json web/$|d' "$DOCKERFILE"
sed -i '\|^COPY ui-tui/package\.json ui-tui/$|d' "$DOCKERFILE"
sed -i '\|^COPY ui-tui/packages/hermes-ink/|d' "$DOCKERFILE"

# 5. Remove frontend build section
sed -i '/^# ---------- Frontend build/,/^    cd \.\.\/ui-tui && npm run build$/d' "$DOCKERFILE"

# 6. Replace uv sync line: reduce extras to matrix, add build deps install + cleanup
awk '
/RUN uv sync --frozen --no-install-project --extra all/ {
    print "RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ make cmake \\"
    print "    && uv sync --frozen --no-install-project --extra matrix \\"
    print "    && uv pip install requests dashscope gradio-client \\"
    # WeChat gateway deps — versions pinned to upstream pyproject.toml extras
    # (qrcode from [messaging], defusedxml from [wecom]).
    # aiohttp is already provided by --extra matrix at 3.14.1, not pinned here.
    print "    && uv pip install qrcode==7.4.2 defusedxml==0.7.1 \\"
    print "    && apt-get remove -y gcc g++ make cmake \\"
    print "    && apt-get autoremove -y \\"
    print "    && rm -rf /var/lib/apt/lists/*"
    next
}
{ print }
' "$DOCKERFILE" > "$DOCKERFILE.tmp" && mv "$DOCKERFILE.tmp" "$DOCKERFILE"

# Remove unused env vars
sed -i '/^ENV HERMES_WEB_DIST=/d' "$DOCKERFILE"
sed -i '/^ENV HERMES_TUI_DIR=/d' "$DOCKERFILE"

echo "Dockerfile patched successfully"
