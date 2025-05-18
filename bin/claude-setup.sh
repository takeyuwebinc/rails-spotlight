#!/usr/bin/env bash

# Install Claude Code npm package
npm install -g @anthropic-ai/claude-code

# Install Puppeteer/Chromium dependencies
echo "Installing Puppeteer/Chromium dependencies..."
./bin/install-puppeteer-deps.sh
