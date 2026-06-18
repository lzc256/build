#!/bin/bash
# Fix frontend static files path for production image.
#
# Problem: Dockerfile copies frontend files but the directory may be empty if
# frontend compilation failed. spa_helper.py expects manifest.json at:
#   ${INVENTREE_BACKEND_DIR}/InvenTree/web/static/web/.vite/manifest.json
#
# This patch modifies the Dockerfile to:
# 1. Verify frontend files exist after COPY
# 2. Fail build if frontend is missing
#
# Files affected:
#   - contrib/container/Dockerfile
#
# Usage: apply_patch 04-fix-frontend-path <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

DOCKERFILE="$TARGET_DIR/contrib/container/Dockerfile"

if [ -f "$DOCKERFILE" ]; then
    echo "Patching: $DOCKERFILE"

    # Add verification after the COPY command for frontend files
    # The COPY puts files at ${INVENTREE_BACKEND_DIR}/InvenTree/web/static/web
    # We verify that .vite/manifest.json exists
    perl -i.bak -0pe 's/(COPY --from=builder_stage \$\{INVENTREE_BACKEND_DIR\}\/InvenTree\/web\/static\/web \$\{INVENTREE_BACKEND_DIR\}\/InvenTree\/web\/static\/web\nCOPY --from=builder_stage \/root\/\.local \/root\/\.local)/$1\n\n# Verify frontend files are present\nRUN test -f \${INVENTREE_BACKEND_DIR}\/InvenTree\/web\/static\/web\/.vite\/manifest.json || \\\n    (echo "ERROR: Frontend manifest.json not found. Frontend compilation may have failed." \&\& exit 1)/g' "$DOCKERFILE"

    rm -f "$DOCKERFILE.bak"
    echo "  - Patched $DOCKERFILE"
fi

echo "Frontend path fix applied:"
echo "  - Dockerfile: Added verification for frontend manifest.json"
