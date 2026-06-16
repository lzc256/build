#!/bin/bash
# Remap hermes user UID/GID from 10000 to 1000:1000
# Some PaaS runtime environments (e.g. fly.io, Railway) expect the container
# process to run as UID 1000; the upstream default 10000 causes permission
# errors on mounted volumes.
#
# Usage: apply_patch uid-remap <target_dir>

set -e

DOCKERFILE="$1/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

sed -i 's/useradd -u 10000/useradd -u 1000/' "$DOCKERFILE"

echo "Dockerfile uid-remap patched: hermes user 10000 -> 1000"
