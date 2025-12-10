#!/bin/bash
# boot.sh - Runs on every codespace start
# Only installs and starts CLIs that are enabled

# Get codespace name from environment or hostname
CODESPACE_NAME="${CODESPACE_NAME:-$(hostname)}"

echo ""
echo "========================================"
echo "  NodeBay Workspace Starting..."
echo "========================================"
echo "Codespace: $CODESPACE_NAME"
echo ""

# Find config file
CONFIG_FILE=""
for f in /workspaces/*/nodebay-config.json; do
  [ -f "$f" ] && CONFIG_FILE="$f" && break
done

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "No CLI enabled yet. Waiting for configuration..."
  echo "Enable a CLI from the NodeBay dashboard."
  exit 0
fi

echo "Config: $CONFIG_FILE"
cat "$CONFIG_FILE"
echo ""

# Helper to check if CLI is enabled
is_enabled() {
  jq -r ".$1.enabled // false" "$CONFIG_FILE" 2>/dev/null | grep -q "true"
}

# Check what's enabled
ENABLED=""
for cli in claude codex gemini copilot; do
  is_enabled "$cli" && ENABLED="$ENABLED $cli"
done

if [ -z "$ENABLED" ]; then
  echo "No CLIs enabled. Waiting..."
  exit 0
fi

echo "Enabled CLIs:$ENABLED"
echo ""

# Get workspace dir
WORKSPACE_DIR=$(dirname "$CONFIG_FILE")

# Clean up old processes
pkill -f ttyd 2>/dev/null || true
tmux kill-server 2>/dev/null || true
sleep 1

# Port mapping
declare -A PORTS=( ["claude"]=7681 ["codex"]=7682 ["gemini"]=7683 ["copilot"]=7684 )

# Install and start each enabled CLI
for cli in $ENABLED; do
  echo "Setting up $cli..."
  
  # Install dependencies and CLI
  case $cli in
    claude)
      if ! command -v claude &>/dev/null; then
        echo "  Installing Claude CLI..."
        curl -fsSL https://claude.ai/install.sh 2>/dev/null | sh || true
        echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.bashrc
      fi
      export PATH="$HOME/.claude/bin:$PATH"
      ;;
    codex)
      if ! command -v codex &>/dev/null; then
        echo "  Installing Node.js and Codex..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >/dev/null 2>&1
        sudo apt-get install -y -qq nodejs >/dev/null 2>&1
        npm install -g @openai/codex 2>/dev/null || true
      fi
      ;;
    gemini)
      echo "  Installing Gemini..."
      sudo apt-get install -y -qq python3-pip >/dev/null 2>&1 || true
      pip install -q google-generativeai 2>/dev/null || true
      ;;
    copilot)
      if ! command -v github-copilot-cli &>/dev/null; then
        echo "  Installing Node.js and Copilot..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >/dev/null 2>&1
        sudo apt-get install -y -qq nodejs >/dev/null 2>&1
        npm install -g @githubnext/github-copilot-cli 2>/dev/null || true
      fi
      ;;
  esac
  
  # Create workspace directory
  dir="$WORKSPACE_DIR/dev/$cli"
  mkdir -p "$dir"
  
  # Clone repo if configured
  repo=$(jq -r ".$cli.repo // \"\"" "$CONFIG_FILE" 2>/dev/null)
  if [ -n "$repo" ] && [ "$repo" != "" ] && [ ! -d "$dir/.git" ]; then
    echo "  Cloning $repo..."
    git clone "$repo" "$dir" 2>/dev/null || true
  fi
  
  # Start tmux session
  tmux new-session -d -s "$cli" -c "$dir" 2>/dev/null || true
  tmux send-keys -t "$cli" "clear && echo '=== $cli CLI ===' && echo 'Dir: $dir'" Enter
  
  # Start ttyd
  port=${PORTS[$cli]}
  echo "  Starting terminal on port $port..."
  ttyd -p "$port" -W tmux attach-session -t "$cli" &
  
  # Make port public (requires gh cli)
  sleep 2
  if command -v gh &>/dev/null; then
    echo "  Setting port $port to public..."
    gh codespace ports visibility "$port:public" -c "$CODESPACE_NAME" 2>/dev/null || true
  fi
done

echo ""
echo "========================================"
echo "  NodeBay Workspace Ready!"
echo "========================================"
echo ""
echo "Enabled:$ENABLED"
echo ""

# Keep alive
while true; do sleep 300; done
