#!/bin/bash
# Remove weasyprint imports from Python source files.
#
# This patch modifies Python source files to remove weasyprint dependencies
# so the application can start without weasyprint installed.
#
# Note: PDF generation will not work after this patch.
#
# Files affected:
#   - src/backend/InvenTree/report/models.py
#   - src/backend/InvenTree/report/fetcher.py
#   - src/backend/InvenTree/plugin/builtin/labels/label_sheet.py
#
# Usage: apply_patch 03-remove-weasyprint-code <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

# 1. Patch report/models.py - remove weasyprint import and exit
MODELS_FILE="$TARGET_DIR/src/backend/InvenTree/report/models.py"
if [ -f "$MODELS_FILE" ]; then
    echo "Patching: $MODELS_FILE"
    # Replace the try/except block that imports weasyprint
    sed -i.bak 's/from weasyprint import HTML/HTML = None  # weasyprint removed/' "$MODELS_FILE"
    sed -i.bak 's/from report.fetcher import InvenTreeURLFetcher/InvenTreeURLFetcher = None/' "$MODELS_FILE"
    sed -i.bak 's/sys.exit(1)/pass/' "$MODELS_FILE"
    rm -f "$MODELS_FILE.bak"
fi

# 2. Patch report/fetcher.py - remove URLFetcher inheritance
FETCHER_FILE="$TARGET_DIR/src/backend/InvenTree/report/fetcher.py"
if [ -f "$FETCHER_FILE" ]; then
    echo "Patching: $FETCHER_FILE"
    sed -i.bak 's/from weasyprint.urls import URLFetcher/URLFetcher = object  # weasyprint removed/' "$FETCHER_FILE"
    sed -i.bak 's/class InvenTreeURLFetcher(URLFetcher):/class InvenTreeURLFetcher:/' "$FETCHER_FILE"
    # Note: super().__init__ call will fail, but the class won't be used
    rm -f "$FETCHER_FILE.bak"
fi

# 3. Patch plugin/builtin/labels/label_sheet.py
LABEL_FILE="$TARGET_DIR/src/backend/InvenTree/plugin/builtin/labels/label_sheet.py"
if [ -f "$LABEL_FILE" ]; then
    echo "Patching: $LABEL_FILE"
    sed -i.bak 's/^import weasyprint$/weasyprint = None  # weasyprint removed/' "$LABEL_FILE"
    sed -i.bak 's/from report.fetcher import InvenTreeURLFetcher/InvenTreeURLFetcher = None/' "$LABEL_FILE"
    rm -f "$LABEL_FILE.bak"
fi

echo "Weasyprint code removal applied:"
echo "  - report/models.py: Removed weasyprint import"
echo "  - report/fetcher.py: Removed URLFetcher inheritance"
echo "  - plugin/builtin/labels/label_sheet.py: Removed weasyprint import"