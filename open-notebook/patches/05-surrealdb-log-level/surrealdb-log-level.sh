#!/bin/bash
# Reduce SurrealDB log level from trace to warn.
#
# Upstream sets --log trace which is very verbose. For production use,
# --log warn is more appropriate (only warnings and errors).
#
# Files affected:
#   - supervisord.single.conf
#
# Usage: apply_patch 05-surrealdb-log-level <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

CONFFILE="$TARGET_DIR/supervisord.single.conf"

if [ ! -f "$CONFFILE" ]; then
    echo "Error: $CONFFILE not found"
    exit 1
fi

echo "Patching: $CONFFILE"

if grep -q "surreal start --log warn" "$CONFFILE"; then
    echo "  Already patched, skipping."
    exit 0
fi

# Replace --log trace with --log warn
sed -i.bak 's/surreal start --log trace/surreal start --log warn/' "$CONFFILE"
rm -f "$CONFFILE.bak"

echo "surrealdb log level: trace -> warn"
