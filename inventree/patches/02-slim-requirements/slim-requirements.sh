#!/bin/bash
# Remove unnecessary Python dependencies from requirements.
#
# This patch removes Python packages that depend on the removed system packages:
#   - weasyprint (PDF generation, depends on pango/cairo)
#   - django-auth-ldap (LDAP authentication)
#   - python-ldap (LDAP library)
#   - mariadb (MariaDB connector, requires libmariadb-dev)
#
# Files affected:
#   - contrib/container/requirements.txt
#
# Usage: apply_patch 02-slim-requirements <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

REQ_FILE="$TARGET_DIR/contrib/container/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
    echo "Error: $REQ_FILE not found"
    exit 1
fi

echo "Patching: $REQ_FILE"

# Remove weasyprint and its dependencies
# Note: requirements.txt uses pip hash format, so we need to delete entire lines
sed -i.bak '/weasyprint/d' "$REQ_FILE"

# Remove LDAP packages
sed -i.bak '/django-auth-ldap/d' "$REQ_FILE"
sed -i.bak '/python-ldap/d' "$REQ_FILE"

# Remove MariaDB connector (requires libmariadb-dev which we removed)
sed -i.bak '/^mariadb==/d' "$REQ_FILE"

# Remove mysqlclient (requires MySQL/MariaDB client libraries which we removed)
sed -i.bak '/^mysqlclient==/d' "$REQ_FILE"

rm -f "$REQ_FILE.bak"

echo "Slim requirements patch applied:"
echo "  - Removed: weasyprint"
echo "  - Removed: django-auth-ldap"
echo "  - Removed: python-ldap"
echo "  - Removed: mariadb"
echo "  - Removed: mysqlclient"