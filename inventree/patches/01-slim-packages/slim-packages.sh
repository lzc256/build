#!/bin/bash
# Remove unnecessary packages from Dockerfile for slim build.
#
# This patch modifies the InvenTree Dockerfile to remove packages that are
# not needed for a minimal SQLite-only deployment without PDF/LDAP support.
#
# Removed packages:
#   - postgresql-client, mariadb-client (SQLite only)
#   - weasyprint, libpango-1.0-0, libcairo2, poppler-utils (no PDF)
#   - fonts-noto-cjk, fonts-noto-core (minimal fonts)
#   - libldap2 (no LDAP auth)
#   - libldap2-dev, libsasl2-dev, libmariadb-dev (build deps)
#
# Files affected:
#   - contrib/container/Dockerfile
#
# Usage: apply_patch 01-slim-packages <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

DOCKERFILE="$TARGET_DIR/contrib/container/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: $DOCKERFILE not found"
    exit 1
fi

echo "Patching: $DOCKERFILE"

# Check if already patched
if grep -q "# SLIM BUILD" "$DOCKERFILE"; then
    echo "  Already patched, skipping."
    exit 0
fi

# Replace the entire apt-get install block in inventree_base
# The original block has this structure:
#   git gettext libldap2 wget curl ssh \
#   # Weasyprint requirements : ...
#   weasyprint libpango-1.0-0 libcairo2 poppler-utils \
#   # Database client libraries
#   postgresql-client mariadb-client \
#   # font support
#   fontconfig fonts-freefont-ttf fonts-terminus fonts-noto-core fonts-noto-cjk \

# We use perl for multi-line replacement
perl -i.bak -0pe 's/RUN apt-get update && apt-get install -y --no-install-recommends \\\n    git gettext libldap2 wget curl ssh \\\n    # Weasyprint requirements : https:\/\/doc\.courtbouillon\.org\/weasyprint\/stable\/first_steps\.html#alpine-3-12\n    weasyprint libpango-1\.0-0 libcairo2 poppler-utils \\\n    # Database client libraries\n    postgresql-client mariadb-client \\\n    # font support\n    fontconfig fonts-freefont-ttf fonts-terminus fonts-noto-core fonts-noto-cjk \\/RUN apt-get update \&\& apt-get install -y --no-install-recommends \\\n    # SLIM BUILD: removed libldap2, weasyprint, database clients, extra fonts\n    git gettext wget curl ssh \\\n    fontconfig fonts-freefont-ttf fonts-terminus \\/g' "$DOCKERFILE"

# Replace the build dependencies block in builder_stage
perl -i.bak -0pe 's/RUN apt-get update && apt-get install -y --no-install-recommends \\\n    pkg-config build-essential \\\n    libldap2-dev libsasl2-dev libssl-dev \\\n    libmariadb-dev \\/RUN apt-get update \&\& apt-get install -y --no-install-recommends \\\n    # SLIM BUILD: removed libldap2-dev, libsasl2-dev, libmariadb-dev\n    pkg-config build-essential \\\n    libssl-dev \\/g' "$DOCKERFILE"

rm -f "$DOCKERFILE.bak"

echo "Slim packages patch applied:"
echo "  - Removed: libldap2"
echo "  - Removed: weasyprint, libpango-1.0-0, libcairo2, poppler-utils"
echo "  - Removed: postgresql-client, mariadb-client"
echo "  - Removed: fonts-noto-core, fonts-noto-cjk"
echo "  - Removed build deps: libldap2-dev, libsasl2-dev, libmariadb-dev"