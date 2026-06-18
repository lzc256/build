#!/bin/bash
# Fix frontend static files path for production image.
#
# InvenTree's production Dockerfile copies frontend files to:
#   ${INVENTREE_BACKEND_DIR}/InvenTree/web/static/web/
#
# But Django's collectstatic needs to run to collect them into STATIC_ROOT.
# This patch modifies init.sh to run collectstatic on first startup.
#
# Files affected:
#   - contrib/container/init.sh
#
# Usage: apply_patch 04-fix-frontend-path <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

INIT_FILE="$TARGET_DIR/contrib/container/init.sh"

if [ -f "$INIT_FILE" ]; then
    echo "Patching: $INIT_FILE"

    # Add collectstatic before the final exec
    # Insert before the last line (exec "$@")
    sed -i.bak '/^# Launch the CMD/i\
# Collect static files if frontend exists but STATIC_ROOT is empty\
if [[ -d "${INVENTREE_BACKEND_DIR}/InvenTree/web/static/web" ]] && [[ ! -f "${INVENTREE_STATIC_ROOT}/web/index.html" ]]; then\
    echo "Collecting static files..."\
    cd ${INVENTREE_BACKEND_DIR}/InvenTree\
    python3 manage.py collectstatic --no-input --verbosity 0\
    cd ${INVENTREE_HOME}\
fi\
' "$INIT_FILE"

    rm -f "$INIT_FILE.bak"
    echo "  - Patched $INIT_FILE"
fi

echo "Frontend path fix applied:"
echo "  - init.sh: Added collectstatic on first startup"
