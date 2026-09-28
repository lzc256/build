#!/bin/bash
# Reduce SurrealDB log level from trace to warn when the single-container
# supervisor configuration is present.
set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

patched=0
for conffile in "$TARGET_DIR/supervisord.single.conf" "$TARGET_DIR/supervisord.conf"; do
    if [ ! -f "$conffile" ]; then
        continue
    fi

    if grep -q 'surreal start --log trace' "$conffile"; then
        sed -i.bak 's/surreal start --log trace/surreal start --log warn/' "$conffile"
        rm -f "$conffile.bak"
        echo "surrealdb log level: trace -> warn ($conffile)"
        patched=1
    elif grep -q 'surreal start --log warn' "$conffile"; then
        echo "Already patched: $conffile"
        patched=1
    fi
done

if [ "$patched" -eq 0 ]; then
    echo "No matching SurrealDB supervisor command found; skipping."
fi
