#!/usr/bin/env bash

# Make script exit if any command fails
set -e

echo "Installing Chromium dependencies for Puppeteer..."

# Update package lists
sudo apt-get update

# Install dependencies required by Chromium
# These are the minimal dependencies needed for Puppeteer/Chromium to work
sudo apt-get install -y \
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
    xdg-utils

# Additional dependencies that might be needed for more complex scenarios
sudo apt-get install -y \
    libnss3-dev \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libxss1

echo "Chromium dependencies installed successfully!"
echo "Browser actions should now work properly."
