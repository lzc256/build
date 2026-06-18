FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# Install essential runtime dependencies for Linux QQ
# Removed: ffmpeg (~150MB), libnotify4, libsecret-1-0, gnutls-bin, libglib2.0-dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 \
    libgbm1 \
    libasound2 \
    libgtk-3-0 \
    libxss1 \
    libxtst6 \
    libatspi2.0-0 \
    libx11-xcb1 \
    libdbus-1-3 \
    xvfb \
    fonts-wqy-zenhei \
    curl \
    jq \
    unzip \
    gosu \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd --no-log-init -d /app napcat

WORKDIR /app

# Download and install Linux QQ
RUN arch=$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/') && \
    QQ_URL="https://dldir1.qq.com/qqfile/qq/QQNT/Ad687dd2/linuxqq_3.2.17-29689_${arch}.deb" && \
    curl -fL --retry 3 -o linuxqq.deb "$QQ_URL" && \
    dpkg -i --force-depends linuxqq.deb && \
    rm linuxqq.deb

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
