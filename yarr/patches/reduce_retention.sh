#!/bin/bash
DESCRIPTION="Reduce retention: keep days from 90→30, min items from 50→20"

# SQLite storage backend
sed -i '' 's/itemsKeepSize = 50/itemsKeepSize = 20/' "$1/src/storage/sqlite/item.go"
sed -i '' 's/itemsKeepDays = 90/itemsKeepDays = 30/' "$1/src/storage/sqlite/item.go"

# Postgres storage backend
sed -i '' 's/itemsKeepSize = 50/itemsKeepSize = 20/' "$1/src/storage/postgres/item.go"
sed -i '' 's/itemsKeepDays = 90/itemsKeepDays = 30/' "$1/src/storage/postgres/item.go"

# Update comment in sqlite backend
sed -i '' 's/Keep at least 50 latest items/Keep at least 20 latest items/' "$1/src/storage/sqlite/item.go"
sed -i '' 's/older than 90 days/older than 30 days/' "$1/src/storage/sqlite/item.go"

# Update test expectations
sed -i '' 's/keeps at least 50 items/keeps at least 20 items/' "$1/src/storage/tests/item_test.go"
sed -i '' 's/keeps all less than 90 days old/keeps all less than 30 days old/' "$1/src/storage/tests/item_test.go"
sed -i '' 's/50 (limit)/20 (limit)/' "$1/src/storage/tests/item_test.go"
