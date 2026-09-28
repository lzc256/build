#!/bin/bash
# Reduce retention limits without relying on source line numbers.
set -e

TARGET_DIR="$1"
for file in "$TARGET_DIR/src/storage/postgres/item.go" "$TARGET_DIR/src/storage/sqlite/item.go"; do
    if [ ! -f "$file" ]; then
        echo "Error: $file not found"
        exit 1
    fi
    if ! grep -q 'itemsKeepSize = 50' "$file" || ! grep -q 'itemsKeepDays = 90' "$file"; then
        if grep -q 'itemsKeepSize = 20' "$file" && grep -q 'itemsKeepDays = 30' "$file"; then
            echo "Already patched: $file"
            continue
        fi
        echo "Error: expected retention values not found in $file"
        exit 1
    fi
    perl -i -0pe 's/itemsKeepSize = 50/itemsKeepSize = 20/; s/itemsKeepDays = 90/itemsKeepDays = 30/' "$file"
    echo "Retention reduced: $file"
done
