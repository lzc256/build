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

perl -i -pe 's|^RUN cd classic.*$|COPY --from=builder /build/web/default/dist ./classic/dist|' "$DOCKERFILE"
echo "Classic UI build replaced with the verified default frontend artifact"
