#!/bin/bash
# Increase the Fever API item limit without relying on source line numbers.
set -e

TARGET_DIR="$1"
FILE="$TARGET_DIR/src/server/fever.go"
if [ ! -f "$FILE" ]; then
    echo "Error: $FILE not found"
    exit 1
fi

if grep -q 'const listLimit = 512' "$FILE"; then
    echo "Fever item limit already increased"
    exit 0
fi

if ! grep -q 'const listLimit = 50' "$FILE"; then
    echo "Error: expected Fever list limit was not found in $FILE"
    exit 1
fi

perl -i -0pe 's/const listLimit = 50/const listLimit = 512/' "$FILE"
echo "Fever item limit: 50 -> 512"
