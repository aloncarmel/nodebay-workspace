#!/bin/bash
# install-base.sh - Runs ONCE when codespace is created
# Only installs base tools (tmux, ttyd, jq)
# CLI tools are installed on-demand when enabled

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       NodeBay Workspace - Base Setup                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Started at: $(date)"

# ============================================
# INSTALL BASE TOOLS ONLY
# ============================================

echo "📦 Installing base tools..."

sudo apt-get update -qq

sudo apt-get install -y -qq \
  tmux \
  jq \
  curl \
  wget \
  lsof

# Install ttyd
echo "🖥️  Installing ttyd..."
TTYD_VERSION="1.7.4"
wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" -O /tmp/ttyd
chmod +x /tmp/ttyd
sudo mv /tmp/ttyd /usr/local/bin/ttyd

echo ""
echo "✅ Base setup complete!"
echo "   CLIs will be installed when you enable them via NodeBay."
echo ""

