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

set -e

DOCKERFILE="$1/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

echo "Patching Dockerfile: $DOCKERFILE"

# 1. Base image: debian:13.4 -> debian:13.4-slim
# Match exactly "FROM debian:13.4" (not followed by -slim)
sed -i 's|^FROM debian:13\.4$|FROM debian:13.4-slim|' "$DOCKERFILE"

# 2. Remove build packages: gcc g++ make cmake
sed -i 's/ gcc g++ make cmake//' "$DOCKERFILE"

# 3. Remove openssh-client docker-cli
sed -i 's/ openssh-client docker-cli//' "$DOCKERFILE"

# 4. Remove web/ui-tui package.json COPY lines (lines that start with COPY and reference web/ui-tui package.json)
sed -i '/^COPY web\/package\.json web\/$/d' "$DOCKERFILE"
sed -i '/^COPY ui-tui\/package\.json ui-tui\/$/d' "$DOCKERFILE"
sed -i '/^COPY ui-tui\/packages\/hermes-ink\//d' "$DOCKERFILE"

# 5. Remove frontend build section (COPY web/ web/, COPY ui-tui/ ui-tui/, and the RUN cd web ... npm run build block)
# This is a multi-line block, we use a range pattern to delete from COPY web/ to npm run build
sed -i '/^COPY web\/ web\/$/,/^RUN cd web && npm run build/d' "$DOCKERFILE"

# 6. Remove the orphaned COPY ui-tui/ ui-tui/ line if still present (part of removed block)
sed -i '/^COPY ui-tui\/ ui-tui\/$/d' "$DOCKERFILE"

# 7. Reduce uv extras: remove all --extra flags from uv sync command
# Keep only: uv sync --frozen --no-install-project
sed -i 's/--extra all --extra messaging --extra anthropic --extra bedrock --extra azure-identity --extra hindsight --extra matrix//' "$DOCKERFILE"

echo "Dockerfile patched successfully"
