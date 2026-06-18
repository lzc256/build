# Use upstream base image which already has Linux QQ installed
# This avoids timeout issues downloading from dldir1.qq.com in CI
FROM mlikiowa/napcat-docker:base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# Create user
RUN useradd --no-log-init -d /app napcat

WORKDIR /app

# Download NapCat latest release
RUN NAPCAT_URL=$(curl -s https://api.github.com/repos/NapNeko/NapCatQQ/releases/latest | \
    jq -r '.assets[] | select(.name | test("NapCat.Shell.zip$")) | .browser_download_url') && \
    curl -fL -o NapCat.Shell.zip "$NAPCAT_URL"

# Copy entrypoint and templates (保留核心逻辑)
COPY entrypoint.sh templates /app/

# Create NapCat loader
RUN echo "(async () => {await import('file:///app/napcat/napcat.mjs');})();" > /opt/QQ/resources/app/loadNapCat.js && \
    sed -i 's|"main": "[^"]*"|"main": "./loadNapCat.js"|' /opt/QQ/resources/app/package.json && \
    chmod +x /app/entrypoint.sh

VOLUME /app/napcat/config
VOLUME /app/.config/QQ

ENTRYPOINT ["bash", "/app/entrypoint.sh"]
