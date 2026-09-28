#!/bin/bash
# Patch Dockerfile for minimal hermes-agent build
# Usage: apply_patch dockerfile-patch <target_dir>
#
# Modifications:
# 1. Base image: debian:13.4 -> debian:13.4-slim
# 2. Remove build packages from apt-get (will reinstall temporarily in uv sync RUN)
# 3. Remove openssh-client docker-cli
# 4. Remove web/ui-tui COPY statements and frontend build
# 5. Reduce uv extras (keep matrix)
# 6. Add extra packages:
#    - requests dashscope gradio-client (general utilities)
#    - aiohttp==3.13.4 qrcode==7.4.2 (weixin/personal WeChat gateway: HTTP client + scan-login QR rendering)
#    - defusedxml==0.7.1 (wecom callback gateway: safe XML parsing for untrusted WeCom POST bodies)
#    These are pinned to match upstream pyproject.toml's [messaging] / [wecom] extras.
# 7. Single RUN for uv sync: install build deps, sync, remove build deps

set -e

DOCKERFILE="$1/Dockerfile"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

echo "Patching Dockerfile: $DOCKERFILE"

perl -i -pe 's|^FROM debian:13\.4$|FROM debian:13.4-slim|' "$DOCKERFILE"

# 2. Keep gcc/g++/make/cmake in the shared runtime base. The matrix extra
# still builds python-olm in the separate python_deps stage, so removing these
# packages from the base makes that stage fail with "make: not found".

# 3. Remove openssh-client docker-cli
perl -i -pe 's/ openssh-client docker-cli//' "$DOCKERFILE"

# Keep web/package.json for the frontend stage; only the obsolete ui-tui
# package inputs are removed.
perl -i -ne 'print unless /^COPY ui-tui\/package\.json ui-tui\/$/' "$DOCKERFILE"
perl -i -ne 'print unless /^COPY ui-tui\/packages\/hermes-ink\//' "$DOCKERFILE"

# 5. Keep the web frontend build: runtime assembly requires
# hermes_cli/web_dist. Only remove the obsolete ui-tui workspace inputs and
# request the current dependency helper to build the web workspace.
perl -i -ne 'print unless /^COPY ui-tui\/package\.json ui-tui\/$/' "$DOCKERFILE"
perl -i -ne 'print unless /^COPY ui-tui\/packages\/hermes-ink\//' "$DOCKERFILE"
perl -i -pe 's/--workspace ui-tui --workspace web/--workspace web/' "$DOCKERFILE"

# 6. Replace uv sync line: reduce extras to matrix, add build deps install + cleanup
awk '
/RUN uv sync --frozen --no-install-project --extra all/ {
    print "RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ make cmake \\"
    print "    && uv sync --frozen --no-install-project --extra matrix \\"
    print "    && uv pip install requests dashscope gradio-client \\"
    # WeChat gateway deps — versions pinned to upstream pyproject.toml extras
    # (qrcode from [messaging], defusedxml from [wecom]).
    # aiohttp is already provided by --extra matrix at 3.14.1, not pinned here.
    print "    && uv pip install qrcode==7.4.2 defusedxml==0.7.1 \\"
    print "    && rm -rf /var/lib/apt/lists/*"
    next
}
{ print }
' "$DOCKERFILE" > "$DOCKERFILE.tmp" && mv "$DOCKERFILE.tmp" "$DOCKERFILE"

# Keep frontend environment variables: the runtime assembler and launcher use
# them even when the TUI source workspace is omitted.

echo "Dockerfile patched successfully"
