#!/bin/bash
# Install the complete workspace dependency graph for the legacy classic UI.
# The filtered install omits transitive packages used by Semi UI (date-fns).
set -e

TARGET_DIR="$1"
DOCKERFILE="$TARGET_DIR/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: $DOCKERFILE not found"
    exit 1
fi

if grep -q 'RUN bun install --filter ./classic --frozen-lockfile' "$DOCKERFILE"; then
    perl -i -pe 's/RUN bun install --filter \.\/classic --frozen-lockfile/RUN bun install --frozen-lockfile/' "$DOCKERFILE"
    echo "Classic UI now installs the complete workspace dependency graph"
elif grep -q 'RUN bun install --frozen-lockfile' "$DOCKERFILE"; then
    echo "Classic UI dependency install already uses the complete workspace"
else
    echo "Error: classic UI dependency install command not found"
    exit 1
fi
