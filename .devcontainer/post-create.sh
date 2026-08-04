#!/usr/bin/env bash

# Add ~/.local/bin to PATH for the current session and persist it
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Install Claude Code (Native Build)
curl -fsSL https://claude.ai/install.sh | bash

# Install Sentry CLI
curl -sL https://sentry.io/get-cli/ | bash

# Install Puppeteer/Chromium dependencies
npm install -g puppeteer
