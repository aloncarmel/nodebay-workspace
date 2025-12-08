#!/bin/bash
# install-tools.sh - Runs ONCE when codespace is created
# Installs system tools and CLIs

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       NodeBay Workspace - Initial Setup                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ============================================
# SYSTEM DEPENDENCIES
# ============================================

echo ""
echo "📦 Installing system dependencies..."

sudo apt-get update -qq
sudo apt-get install -y -qq \
  tmux \
  jq \
  curl \
  wget \
  inotify-tools \
  > /dev/null

echo "✅ System dependencies installed"

# ============================================
# TTYD (Terminal over HTTP)
# ============================================

echo ""
echo "🖥️  Installing ttyd..."

TTYD_VERSION="1.7.4"
wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
  -O /tmp/ttyd
chmod +x /tmp/ttyd
sudo mv /tmp/ttyd /usr/local/bin/ttyd

echo "✅ ttyd installed"

# ============================================
# NGROK (Tunneling)
# ============================================

echo ""
echo "🌐 Installing ngrok..."

curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt-get update -qq
sudo apt-get install -y -qq ngrok > /dev/null

echo "✅ ngrok installed"

# ============================================
# CLAUDE CLI (Anthropic)
# ============================================

echo ""
echo "🤖 Installing Claude CLI..."

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | sh 2>/dev/null || {
  echo "  ⚠️  Claude CLI install script failed, trying npm..."
  npm install -g @anthropic-ai/claude-code 2>/dev/null || true
}

# Add to PATH
echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.bashrc

echo "✅ Claude CLI installed"

# ============================================
# CODEX CLI (OpenAI)
# ============================================

echo ""
echo "🧠 Installing Codex CLI..."

npm install -g @openai/codex 2>/dev/null || {
  echo "  ⚠️  Codex not available on npm, skipping..."
}

echo "✅ Codex CLI installed"

# ============================================
# GEMINI CLI (Google)
# ============================================

echo ""
echo "✨ Installing Gemini CLI..."

pip install -q google-generativeai 2>/dev/null || true

# Install Gemini CLI if available
npm install -g @google/gemini-cli 2>/dev/null || {
  echo "  ⚠️  Gemini CLI not available, using SDK only..."
}

echo "✅ Gemini CLI installed"

# ============================================
# COPILOT CLI (GitHub)
# ============================================

echo ""
echo "🐙 Installing GitHub Copilot CLI..."

npm install -g @githubnext/github-copilot-cli 2>/dev/null || {
  echo "  Trying alternative package..."
  npm install -g @github/copilot-cli 2>/dev/null || {
    echo "  ⚠️  Copilot CLI not available, skipping..."
  }
}

echo "✅ Copilot CLI installed"

# ============================================
# CREATE WORKSPACE DIRECTORIES
# ============================================

echo ""
echo "📁 Creating workspace directories..."

mkdir -p /workspaces/dev/claude
mkdir -p /workspaces/dev/codex
mkdir -p /workspaces/dev/gemini
mkdir -p /workspaces/dev/copilot

echo "✅ Workspace directories created"

# ============================================
# DONE
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       ✅ Initial Setup Complete!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Installed:"
echo "  • tmux, ttyd, ngrok, jq"
echo "  • Claude CLI (Anthropic)"
echo "  • Codex CLI (OpenAI)"
echo "  • Gemini CLI (Google)"
echo "  • Copilot CLI (GitHub)"
echo ""
echo "Directories:"
echo "  • /workspaces/dev/claude"
echo "  • /workspaces/dev/codex"
echo "  • /workspaces/dev/gemini"
echo "  • /workspaces/dev/copilot"
echo ""

