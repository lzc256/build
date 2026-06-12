#!/bin/bash
# Patch Dockerfile for minimal hermes-agent build
# Usage: apply_patch dockerfile-patch <target_dir>
#
# Modifications:
# 1. Base image: debian:13.4 -> debian:13.4-slim
# 2. Remove build packages: gcc g++ make cmake
# 3. Remove openssh-client docker-cli
# 4. Remove web/ui-tui COPY statements and frontend build
# 5. Reduce uv extras (remove all --extra flags)
# 6. Add extra packages: requests dashscope gradio-client

set -e

DOCKERFILE="$1/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

echo "Patching Dockerfile: $DOCKERFILE"

# 1. Base image: debian:13.4 -> debian:13.4-slim
sed -i 's|^FROM debian:13\.4$|FROM debian:13.4-slim|' "$DOCKERFILE"

# 2. Remove build packages: gcc g++ make cmake
sed -i 's/ gcc g++ make cmake//' "$DOCKERFILE"

# 3. Remove openssh-client docker-cli
sed -i 's/ openssh-client docker-cli//' "$DOCKERFILE"

# 4. Remove web/ui-tui package.json COPY lines
sed -i '\|^COPY web/package\.json web/$|d' "$DOCKERFILE"
sed -i '\|^COPY ui-tui/package\.json ui-tui/$|d' "$DOCKERFILE"
sed -i '\|^COPY ui-tui/packages/hermes-ink/|d' "$DOCKERFILE"

# 5. Remove frontend build section (lines 177-185: comments + COPY web/ + COPY ui-tui/ + RUN cd web ...)
# Delete from "# ---------- Frontend build" comment block to end of RUN command
sed -i '/^# ---------- Frontend build/,/^    cd \.\.\/ui-tui && npm run build$/d' "$DOCKERFILE"

# 6. Reduce uv extras: remove all --extra flags from uv sync command
sed -i 's/--extra all --extra messaging --extra anthropic --extra bedrock --extra azure-identity --extra hindsight --extra matrix//' "$DOCKERFILE"

# 7. Add extra packages after uv sync
# Insert RUN uv pip install after the uv sync line (may have trailing whitespace)
sed -i '/^RUN uv sync --frozen --no-install-project *$/a RUN uv pip install requests dashscope gradio-client' "$DOCKERFILE"

echo "Dockerfile patched successfully"
