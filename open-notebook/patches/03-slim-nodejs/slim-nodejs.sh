#!/bin/bash
# Replace NodeSource Node.js install with a multi-stage binary copy from
# `node:20-slim`.
#
# Upstream installs Node 20.x from NodeSource via `apt-get install -y nodejs`,
# which pulls ~150 MB into the runtime layer (full toolchain incl. headers,
# npm, manpages, etc.). The standalone Next.js bundle only needs the `node`
# runtime to execute `server.js`. Copying the binary out of the official
# `node:20-slim` image gives us the same Node version with ~70 MB on disk.
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

    # 2. Strip the NodeSource install lines. Upstream form (line-continued):
    #        ... \
    #        && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    #        && apt-get install -y nodejs \
    #        && rm -rf /var/lib/apt/lists/*
    sed -i.bak \
        -e '/curl -fsSL https:\/\/deb\.nodesource\.com\/setup_20\.x | bash -/d' \
        -e '/&& apt-get install -y nodejs/d' \
        "$dockerfile"
    rm -f "$dockerfile.bak"

    # 3. Inject the binary copy just before the first runtime-stage `WORKDIR /app`.
    #    `WORKDIR /app` is a stable anchor that appears once per Dockerfile in
    #    the runtime stage (the builder stages also have one, but we only inject
    #    on the *first occurrence after* `FROM ... AS runtime` — done by tracking
    #    a flag that flips when we see the runtime FROM line).
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
