#!/bin/bash
# Remove weasyprint imports from Python source files.
#
# This patch modifies Python source files to remove weasyprint dependencies
# so the application can start without weasyprint installed.
# When PDF rendering is requested, it silently returns empty bytes instead of crashing.
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

# 1. Patch report/models.py
MODELS_FILE="$TARGET_DIR/src/backend/InvenTree/report/models.py"
if [ -f "$MODELS_FILE" ]; then
    echo "Patching: $MODELS_FILE"
    # Replace weasyprint import with None
    sed -i.bak 's/from weasyprint import HTML/HTML = None  # weasyprint removed/' "$MODELS_FILE"
    sed -i.bak 's/from report.fetcher import InvenTreeURLFetcher/InvenTreeURLFetcher = None/' "$MODELS_FILE"
    sed -i.bak 's/sys.exit(1)/pass/' "$MODELS_FILE"
    # Replace the HTML().write_pdf() call with a silent fallback returning empty bytes
    perl -i.bak -0pe 's/pdf = HTML\(string=html, url_fetcher=InvenTreeURLFetcher\(\)\)\.write_pdf\(\s*pdf_forms=True\s*\)/pdf = b""  # SLIM: weasyprint removed, PDF unavailable/g' "$MODELS_FILE"
    rm -f "$MODELS_FILE.bak"
fi

# 2. Patch report/fetcher.py
FETCHER_FILE="$TARGET_DIR/src/backend/InvenTree/report/fetcher.py"
if [ -f "$FETCHER_FILE" ]; then
    echo "Patching: $FETCHER_FILE"
    sed -i.bak 's/from weasyprint.urls import URLFetcher/URLFetcher = object  # weasyprint removed/' "$FETCHER_FILE"
    sed -i.bak 's/class InvenTreeURLFetcher(URLFetcher):/class InvenTreeURLFetcher:/' "$FETCHER_FILE"
    rm -f "$FETCHER_FILE.bak"
fi

# 3. Patch plugin/builtin/labels/label_sheet.py
LABEL_FILE="$TARGET_DIR/src/backend/InvenTree/plugin/builtin/labels/label_sheet.py"
if [ -f "$LABEL_FILE" ]; then
    echo "Patching: $LABEL_FILE"
    sed -i.bak 's/^import weasyprint$/weasyprint = None  # weasyprint removed/' "$LABEL_FILE"
    sed -i.bak 's/from report.fetcher import InvenTreeURLFetcher/InvenTreeURLFetcher = None/' "$LABEL_FILE"
    # Replace weasyprint.HTML() call + document generation with silent fallback
    perl -i.bak -0pe 's/html = weasyprint\.HTML\(string=html_data, url_fetcher=InvenTreeURLFetcher\(\)\)\n\s*document = html\.render\(\)\.write_pdf\(\)/document = b""  # SLIM: weasyprint removed, PDF unavailable/g' "$LABEL_FILE"
    # Fix generated_file assignment since document is now bytes not a PDF object
    sed -i.bak 's/generated_file = ContentFile(document,/generated_file = ContentFile(html_data.encode() if isinstance(html_data, str) else html_data,/g' "$LABEL_FILE"
    rm -f "$LABEL_FILE.bak"
fi

echo "Weasyprint code removal applied:"
echo "  - report/models.py: Removed weasyprint import, PDF returns empty bytes"
echo "  - report/fetcher.py: Removed URLFetcher inheritance"
echo "  - plugin/builtin/labels/label_sheet.py: Removed weasyprint import, PDF returns empty bytes"