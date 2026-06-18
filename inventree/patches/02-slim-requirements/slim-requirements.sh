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
# Optional removals (controlled by SLIM_NO_S3 env var):
#   - boto3, botocore, s3transfer (AWS S3 storage)
#   - xmlsec, python3-saml (SAML authentication)
#   - grpcio, opentelemetry-exporter-otlp-proto-grpc (gRPC telemetry export)
#
# Files affected:
#   - contrib/container/requirements.txt
#   - src/backend/requirements.txt
#
# Usage: apply_patch 02-slim-requirements <target_dir>
#
# Environment variables:
#   SLIM_NO_S3=1  Also remove AWS S3/SAML/gRPC dependencies (default: 0)

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

    # Optional: remove S3/SAML/gRPC dependencies
    if [ "${SLIM_NO_S3:-0}" = "1" ]; then
        echo "  SLIM_NO_S3=1: Removing S3/SAML/gRPC dependencies"
        sed -i.bak '/^boto3==/d' "$REQ_FILE"
        sed -i.bak '/^botocore==/d' "$REQ_FILE"
        sed -i.bak '/^s3transfer==/d' "$REQ_FILE"
        sed -i.bak '/^xmlsec==/d' "$REQ_FILE"
        sed -i.bak '/^python3-saml==/d' "$REQ_FILE"
        sed -i.bak '/^grpcio==/d' "$REQ_FILE"
        sed -i.bak '/^opentelemetry-exporter-otlp-proto-grpc==/d' "$REQ_FILE"
    fi

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

    # Optional: remove S3/SAML/gRPC dependencies
    if [ "${SLIM_NO_S3:-0}" = "1" ]; then
        echo "  SLIM_NO_S3=1: Removing S3/SAML/gRPC dependencies"
        sed -i.bak '/^boto3==/d' "$BACKEND_REQ"
        sed -i.bak '/^botocore==/d' "$BACKEND_REQ"
        sed -i.bak '/^s3transfer==/d' "$BACKEND_REQ"
        sed -i.bak '/^xmlsec==/d' "$BACKEND_REQ"
        sed -i.bak '/^python3-saml==/d' "$BACKEND_REQ"
        sed -i.bak '/^grpcio==/d' "$BACKEND_REQ"
        sed -i.bak '/^opentelemetry-exporter-otlp-proto-grpc==/d' "$BACKEND_REQ"
    fi

    rm -f "$BACKEND_REQ.bak"
    echo "  - Patched $BACKEND_REQ"
fi

echo "Slim requirements patch applied:"
echo "  - Removed: weasyprint"
echo "  - Removed: django-auth-ldap, python-ldap"
echo "  - Removed: mariadb, mysqlclient"
echo "  - Removed: fonttools, pyphen (weasyprint deps)"
if [ "${SLIM_NO_S3:-0}" = "1" ]; then
    echo "  - Removed: boto3, botocore, s3transfer (S3)"
    echo "  - Removed: xmlsec, python3-saml (SAML)"
    echo "  - Removed: grpcio, opentelemetry-exporter-otlp-proto-grpc (gRPC)"
fi