#!/bin/bash
# Remove unnecessary Python dependencies from requirements.
#
# This patch removes Python packages that depend on the removed system packages:
#   - weasyprint (PDF generation, depends on pango/cairo)
#   - django-auth-ldap (LDAP authentication)
#   - python-ldap (LDAP library)
#   - mariadb (MariaDB connector, requires libmariadb-dev)
#   - mysqlclient (MySQL connector, requires MySQL client libs)
#
# And cascading dependencies from removed packages:
#   - fonttools (weasyprint dependency)
#   - pyphen (weasyprint dependency)
#
# Also removes opentelemetry-exporter-otlp chain due to missing hashes for grpc variant.
#
# Files affected:
#   - contrib/container/requirements.txt
#   - src/backend/requirements.txt
#
# Usage: apply_patch 02-slim-requirements <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

# Patch contrib/container/requirements.txt
REQ_FILE="$TARGET_DIR/contrib/container/requirements.txt"

if [ -f "$REQ_FILE" ]; then
    echo "Patching: $REQ_FILE"

    # Remove weasyprint and its dependencies
    sed -i.bak '/weasyprint/d' "$REQ_FILE"

    # Remove LDAP packages
    sed -i.bak '/django-auth-ldap/d' "$REQ_FILE"
    sed -i.bak '/python-ldap/d' "$REQ_FILE"

    # Remove MariaDB connector (requires libmariadb-dev which we removed)
    sed -i.bak '/^mariadb==/d' "$REQ_FILE"

    # Remove mysqlclient (requires MySQL/MariaDB client libraries which we removed)
    sed -i.bak '/^mysqlclient==/d' "$REQ_FILE"

    # Remove weasyprint cascading dependencies
    sed -i.bak '/^fonttools/d' "$REQ_FILE"
    sed -i.bak '/^pyphen/d' "$REQ_FILE"

    # Remove opentelemetry-exporter-otlp chain (grpc variant has no hash)
    sed -i.bak '/^opentelemetry-exporter-otlp==/d' "$REQ_FILE"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-grpc==/d' "$REQ_FILE"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-common==/d' "$REQ_FILE"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-http==/d' "$REQ_FILE"
    sed -i.bak '/^grpcio==/d' "$REQ_FILE"

    rm -f "$REQ_FILE.bak"
    echo "  - Patched $REQ_FILE"
fi

# Also patch src/backend/requirements.txt
BACKEND_REQ="$TARGET_DIR/src/backend/requirements.txt"

if [ -f "$BACKEND_REQ" ]; then
    echo "Patching: $BACKEND_REQ"

    # Remove weasyprint and its transitive dependencies
    sed -i.bak '/weasyprint/d' "$BACKEND_REQ"

    # Remove weasyprint cascading dependencies
    sed -i.bak '/^fonttools\[woff\]==/d' "$BACKEND_REQ"
    sed -i.bak '/^pyphen==/d' "$BACKEND_REQ"

    # Remove opentelemetry-exporter-otlp chain (grpc variant has no hash)
    sed -i.bak '/^opentelemetry-exporter-otlp==/d' "$BACKEND_REQ"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-grpc==/d' "$BACKEND_REQ"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-common==/d' "$BACKEND_REQ"
    sed -i.bak '/^opentelemetry-exporter-otlp-proto-http==/d' "$BACKEND_REQ"
    sed -i.bak '/^grpcio==/d' "$BACKEND_REQ"

    rm -f "$BACKEND_REQ.bak"
    echo "  - Patched $BACKEND_REQ"
fi

echo "Slim requirements patch applied:"
echo "  - Removed: weasyprint"
echo "  - Removed: django-auth-ldap, python-ldap"
echo "  - Removed: mariadb, mysqlclient"
echo "  - Removed: fonttools, pyphen (weasyprint deps)"
echo "  - Removed: grpcio, opentelemetry-exporter-otlp (telemetry)"