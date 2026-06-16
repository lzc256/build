#!/bin/bash
# Replace NodeSource Node.js install in the **runtime stage** with a multi-stage
# binary copy from `node:20-slim`.
#
# Upstream installs Node 20.x from NodeSource via `apt-get install -y nodejs`
# in BOTH the builder and runtime stages. The builder needs the full node+npm
# toolchain to run `npm ci` and `npm run build`, so we leave that untouched.
# The runtime only needs the `node` binary to execute the standalone Next.js
# `server.js`, so we replace the NodeSource install with a ~70 MB binary copy.
#
# Files affected:
#   - Dockerfile
#   - Dockerfile.single
#
# Usage: apply_patch 03-slim-nodejs <target_dir>

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

    if grep -q "FROM node:20-slim AS node-runtime" "$dockerfile"; then
        echo "  Already patched, skipping."
        return 0
    fi

    # 1. Inject the node-runtime stage right before the `runtime` stage.
    awk '
        /^FROM .* AS runtime$/ && !injected {
            print "# Slim Node.js runtime: copy just the `node` binary out of node:20-slim"
            print "# instead of installing the full NodeSource package set. The standalone"
            print "# Next.js bundle (`server.js`) only needs the runtime, not npm or headers."
            print "FROM node:20-slim AS node-runtime"
            print ""
            injected = 1
        }
        { print }
    ' "$dockerfile" > "$dockerfile.tmp" && mv "$dockerfile.tmp" "$dockerfile"

    # 2. Strip the NodeSource install lines ONLY in the runtime stage.
    #    We detect the runtime stage by tracking when we've seen `FROM ... AS runtime`
    #    and delete the nodesource lines that appear after it.
    awk '
        /^FROM .* AS runtime$/ { in_runtime = 1 }
        in_runtime && /curl -fsSL https:\/\/deb\.nodesource\.com\/setup_20\.x/ { next }
        in_runtime && /&& apt-get install -y nodejs/ { next }
        { print }
    ' "$dockerfile" > "$dockerfile.tmp" && mv "$dockerfile.tmp" "$dockerfile"

    # 3. Inject the binary copy just before the first runtime-stage `WORKDIR /app`.
    awk '
        /^FROM .* AS runtime$/ { in_runtime = 1 }
        in_runtime && /^WORKDIR \/app$/ && !injected {
            print "# Bring in just the node runtime binary (see node-runtime stage above)."
            print "COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node"
            print ""
            injected = 1
        }
        { print }
    ' "$dockerfile" > "$dockerfile.tmp" && mv "$dockerfile.tmp" "$dockerfile"
}

patch_dockerfile "$TARGET_DIR/Dockerfile"
patch_dockerfile "$TARGET_DIR/Dockerfile.single"

echo "slim-nodejs patch applied"
