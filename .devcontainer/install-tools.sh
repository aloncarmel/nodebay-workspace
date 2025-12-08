#!/bin/bash
# install-tools.sh - Runs ONCE when codespace is created
# Installs system tools and CLIs

# Log everything
exec > >(tee -a /tmp/install-tools.log) 2>&1

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       NodeBay Workspace - Initial Setup                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Started at: $(date)"
echo "User: $(whoami)"
echo "PWD: $(pwd)"
echo ""

# ============================================
# SYSTEM DEPENDENCIES
# ============================================

echo "📦 Installing system dependencies..."

sudo apt-get update -qq || {
  echo "⚠️ apt-get update failed, continuing anyway..."
}

sudo apt-get install -y -qq \
  tmux \
  jq \
  curl \
  wget \
  lsof \
  || {
  echo "⚠️ Some packages failed to install, continuing..."
}

echo "✅ System dependencies installed"

# ============================================
# TTYD (Terminal over HTTP)
# ============================================

echo ""
echo "🖥️  Installing ttyd..."

if command -v ttyd &> /dev/null; then
  echo "  ttyd already installed: $(ttyd --version 2>&1 | head -1)"
else
  TTYD_VERSION="1.7.4"
  wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -O /tmp/ttyd || {
    echo "⚠️ Failed to download ttyd"
  }
  chmod +x /tmp/ttyd
  sudo mv /tmp/ttyd /usr/local/bin/ttyd
  echo "  ✅ ttyd installed"
fi

# ============================================
# NGROK (Tunneling)
# ============================================

echo ""
echo "🌐 Installing ngrok..."

if command -v ngrok &> /dev/null; then
  echo "  ngrok already installed: $(ngrok --version 2>&1)"
else
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
    sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
    sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt-get update -qq
  sudo apt-get install -y -qq ngrok || {
    echo "⚠️ Failed to install ngrok via apt, trying direct download..."
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O /tmp/ngrok.tgz
    tar -xzf /tmp/ngrok.tgz -C /tmp
    sudo mv /tmp/ngrok /usr/local/bin/ngrok
  }
  echo "  ✅ ngrok installed"
fi

# ============================================
# CLAUDE CLI (Anthropic)
# ============================================

echo ""
echo "🤖 Installing Claude CLI..."

if command -v claude &> /dev/null; then
  echo "  Claude CLI already installed"
else
  # Try official installer
  curl -fsSL https://claude.ai/install.sh 2>/dev/null | sh || {
    echo "  ⚠️  Claude CLI install script failed"
    echo "  User can install manually: npm install -g @anthropic-ai/claude-code"
  }
fi

# Add to PATH
echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.bashrc

echo "✅ Claude CLI setup complete"

# ============================================
# CODEX CLI (OpenAI)
# ============================================

echo ""
echo "🧠 Installing Codex CLI..."

if command -v codex &> /dev/null; then
  echo "  Codex CLI already installed"
else
  npm install -g @openai/codex 2>/dev/null || {
    echo "  ⚠️  Codex CLI not available or failed to install"
  }
fi

echo "✅ Codex CLI setup complete"

# ============================================
# GEMINI CLI (Google)
# ============================================

echo ""
echo "✨ Installing Gemini CLI..."

pip install -q google-generativeai 2>/dev/null || {
  echo "  ⚠️  Google AI SDK failed to install"
}

npm install -g @google/gemini-cli 2>/dev/null || {
  echo "  ⚠️  Gemini CLI not available"
}

echo "✅ Gemini CLI setup complete"

# ============================================
# COPILOT CLI (GitHub)
# ============================================

echo ""
echo "🐙 Installing GitHub Copilot CLI..."

npm install -g @githubnext/github-copilot-cli 2>/dev/null || {
  npm install -g @github/copilot-cli 2>/dev/null || {
    echo "  ⚠️  Copilot CLI not available"
  }
}

echo "✅ Copilot CLI setup complete"

# ============================================
# VERIFY INSTALLATIONS
# ============================================

echo ""
echo "📋 Verifying installations..."

check_cmd() {
  if command -v "$1" &> /dev/null; then
    echo "  ✅ $1: $(which $1)"
  else
    echo "  ❌ $1: not found"
  fi
}

check_cmd tmux
check_cmd jq
check_cmd ttyd
check_cmd ngrok
check_cmd node
check_cmd npm
check_cmd python3
check_cmd pip

# ============================================
# DONE
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       ✅ Initial Setup Complete!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Finished at: $(date)"
echo "Log file: /tmp/install-tools.log"
echo ""
