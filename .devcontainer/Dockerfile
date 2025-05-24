# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.2
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install Puppeteer/Chromium dependencies
USER root
RUN apt-get update && apt-get install -y \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxtst6 \
    libdrm2 \
    libxkbcommon0 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcb-dri3-0 \
    fonts-liberation \
    libappindicator1 \
    xdg-utils \
    libnss3-dev \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libxss1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER vscode
