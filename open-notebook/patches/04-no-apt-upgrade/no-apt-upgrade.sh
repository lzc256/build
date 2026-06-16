#!/bin/bash
# Drop `apt-get upgrade -y` from runtime apt blocks.
#
# Upstream runs `apt-get update && apt-get upgrade -y && apt-get install ...`
# in the runtime stage of both Dockerfiles. `upgrade -y` reinstalls every
# package the base image already ships with newer versions in the security
# repo, which inflates the layer by tens of MB and slows builds, while
# adding little real security benefit (the Python base image is rebuilt
# regularly upstream and CVE patching belongs at the base-image level, not
# baked into our final layer).
#
# Files affected:
#   - Dockerfile
#   - Dockerfile.single
#
# Usage: apply_patch 04-no-apt-upgrade <target_dir>

set -e

TARGET_DIR="$1"
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

patch_dockerfile() {
    local dockerfile="$1"

    if [ ! -f "$dockerfile" ]; then
        return 0
    fi

    echo "Patching: $dockerfile"

    # Match both spacings:
    #   "apt-get update && apt-get upgrade -y && apt-get install"
    #   "apt-get update && apt-get upgrade -y &&apt-get install"
    if ! grep -q 'apt-get upgrade -y' "$dockerfile"; then
        echo "  No apt-get upgrade found, skipping."
        return 0
    fi

    sed -i.bak \
        -e 's| && apt-get upgrade -y||g' \
        "$dockerfile"
    rm -f "$dockerfile.bak"
}

patch_dockerfile "$TARGET_DIR/Dockerfile"
patch_dockerfile "$TARGET_DIR/Dockerfile.single"

echo "no-apt-upgrade patch applied"
