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
# 6. Add extra packages: requests dashscope gradio-client
# 7. Single RUN for uv sync: install build deps, sync, remove build deps
# 8. Remove Node.js stage and binaries (Matrix doesn't need Node.js)

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

# 6. Reduce uv extras: keep matrix
sed -i 's/--extra all --extra messaging --extra anthropic --extra bedrock --extra azure-identity --extra hindsight //' "$DOCKERFILE"

# 7. Replace uv sync line with multi-command RUN
awk '
/^RUN uv sync --frozen --no-install-project --extra matrix$/ {
    print "RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ make cmake \\"
    print "    && uv sync --frozen --no-install-project --extra matrix \\"
    print "    && uv pip install requests dashscope gradio-client \\"
    print "    && apt-get remove -y gcc g++ make cmake \\"
    print "    && apt-get autoremove -y \\"
    print "    && rm -rf /var/lib/apt/lists/*"
    next
}
{ print }
' "$DOCKERFILE" > "$DOCKERFILE.tmp" && mv "$DOCKERFILE.tmp" "$DOCKERFILE"

# 8. Remove Node.js stage and all related components (Matrix doesn't need Node.js)
# Remove node:22-bookworm-slim stage and its comment block
sed -i '/^# Node 22 LTS source stage/,/^FROM debian:13\.4-slim$/d' "$DOCKERFILE"

# Remove Node.js binary copies
sed -i '/^COPY --chmod=0755 --from=node_source/d' "$DOCKERFILE"
sed -i '/^COPY --from=node_source/d' "$DOCKERFILE"
sed -i '/ln -sf.*npm-cli.js/d' "$DOCKERFILE"
sed -i '/ln -sf.*npx-cli.js/d' "$DOCKERFILE"
sed -i '/ln -sf.*corepack.js/d' "$DOCKERFILE"

# Remove npm related
sed -i '/^ENV npm_config_install_links=false$/d' "$DOCKERFILE"
sed -i '/^COPY package\.json package-lock\.json \.\//d' "$DOCKERFILE"
sed -i '/npm install --prefer-offline/d' "$DOCKERFILE"
sed -i '/npx playwright install.*chromium/d' "$DOCKERFILE"
sed -i '/npm cache clean/d' "$DOCKERFILE"

# Remove unused env vars
sed -i '/^ENV PLAYWRIGHT_BROWSERS_PATH=/d' "$DOCKERFILE"
sed -i '/^ENV HERMES_WEB_DIST=/d' "$DOCKERFILE"
sed -i '/^ENV HERMES_TUI_DIR=/d' "$DOCKERFILE"

# Remove node_source comment references
sed -i '/# See node_source stage/d' "$DOCKERFILE"

echo "Dockerfile patched successfully"
