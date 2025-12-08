#!/bin/bash
# boot.sh - Runs on EVERY codespace start
# Installs enabled CLIs and starts their ttyd terminals

set +e  # Don't exit on error

# ============================================
# FIND WORKSPACE
# ============================================

WORKSPACE_DIR=$(find /workspaces -maxdepth 1 -type d -name "*" ! -name "." ! -name ".codespaces" 2>/dev/null | head -1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       🚀 NodeBay Workspace Starting...                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "[$(date '+%H:%M:%S')] Workspace: $WORKSPACE_DIR"
echo "[$(date '+%H:%M:%S')] Hostname: $(hostname)"

# ============================================
# LOAD CONFIG
# ============================================

CONFIG_FILE="$WORKSPACE_DIR/nodebay-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[$(date '+%H:%M:%S')] No config file found at $CONFIG_FILE"
  echo "[$(date '+%H:%M:%S')] Waiting for CLI to be enabled via NodeBay..."
  echo ""
  echo "✅ Codespace ready. Enable a CLI from the NodeBay dashboard."
  exit 0
fi

echo "[$(date '+%H:%M:%S')] Config: $CONFIG_FILE"
cat "$CONFIG_FILE"
echo ""

# ============================================
# HELPER FUNCTIONS
# ============================================

get_config() {
  jq -r ".$1.$2 // \"$3\"" "$CONFIG_FILE" 2>/dev/null
}

is_enabled() {
  [ "$(get_config "$1" "enabled" "false")" = "true" ]
}

# ============================================
# CHECK ENABLED CLIs
# ============================================

echo "[$(date '+%H:%M:%S')] Checking enabled CLIs..."

ENABLED=""
for cli in claude codex gemini copilot; do
  if is_enabled "$cli"; then
    ENABLED="$ENABLED $cli"
    echo "  ✅ $cli"
  fi
done

if [ -z "$ENABLED" ]; then
  echo "[$(date '+%H:%M:%S')] No CLIs enabled yet."
  echo ""
  echo "✅ Codespace ready. Enable a CLI from the NodeBay dashboard."
  exit 0
fi

echo ""
echo "[$(date '+%H:%M:%S')] Enabled CLIs:$ENABLED"

# ============================================
# INSTALL ENABLED CLIs
# ============================================

echo ""
echo "[$(date '+%H:%M:%S')] 📦 Installing enabled CLIs..."

install_claude() {
  if command -v claude &> /dev/null; then
    echo "  Claude already installed"
    return
  fi
  echo "  Installing Claude CLI..."
  curl -fsSL https://claude.ai/install.sh 2>/dev/null | sh || {
    echo "  ⚠️ Claude install failed - user can install manually"
  }
  export PATH="$HOME/.claude/bin:$PATH"
  echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.bashrc
}

install_codex() {
  if command -v codex &> /dev/null; then
    echo "  Codex already installed"
    return
  fi
  echo "  Installing Codex CLI..."
  npm install -g @openai/codex 2>/dev/null || {
    echo "  ⚠️ Codex install failed"
  }
}

install_gemini() {
  echo "  Installing Gemini..."
  pip install -q google-generativeai 2>/dev/null || true
  npm install -g @google/gemini-cli 2>/dev/null || true
}

install_copilot() {
  if command -v github-copilot-cli &> /dev/null; then
    echo "  Copilot already installed"
    return
  fi
  echo "  Installing Copilot CLI..."
  npm install -g @githubnext/github-copilot-cli 2>/dev/null || {
    npm install -g @github/copilot-cli 2>/dev/null || true
  }
}

for cli in $ENABLED; do
  install_$cli
done

# ============================================
# CLEANUP OLD PROCESSES
# ============================================

echo ""
echo "[$(date '+%H:%M:%S')] 🧹 Cleaning up..."

pkill -f "ttyd" 2>/dev/null || true
tmux kill-server 2>/dev/null || true
sleep 1

# ============================================
# CREATE DEV DIRECTORIES & CLONE REPOS
# ============================================

echo ""
echo "[$(date '+%H:%M:%S')] 📂 Setting up workspaces..."

for cli in $ENABLED; do
  dir="$WORKSPACE_DIR/dev/$cli"
  mkdir -p "$dir"
  
  repo=$(get_config "$cli" "repo" "")
  branch=$(get_config "$cli" "branch" "main")
  
  if [ -n "$repo" ] && [ "$repo" != "" ]; then
    if [ ! -d "$dir/.git" ]; then
      echo "  Cloning $repo into $dir..."
      git clone --branch "$branch" "$repo" "$dir" 2>/dev/null || {
        echo "  ⚠️ Clone failed, directory left empty"
      }
    else
      echo "  Pulling latest for $cli..."
      cd "$dir" && git pull origin "$branch" 2>/dev/null || true
    fi
  fi
done

# ============================================
# START TMUX SESSIONS & TTYD
# ============================================

echo ""
echo "[$(date '+%H:%M:%S')] 🖥️  Starting terminals..."

# Port mapping
declare -A PORTS=(
  ["claude"]=7681
  ["codex"]=7682
  ["gemini"]=7683
  ["copilot"]=7684
)

declare -A ICONS=(
  ["claude"]="🤖"
  ["codex"]="🧠"
  ["gemini"]="✨"
  ["copilot"]="🐙"
)

declare -A CMDS=(
  ["claude"]="claude"
  ["codex"]="codex"
  ["gemini"]="gemini"
  ["copilot"]="github-copilot-cli"
)

export PATH="$HOME/.claude/bin:$PATH"

for cli in $ENABLED; do
  port=${PORTS[$cli]}
  dir="$WORKSPACE_DIR/dev/$cli"
  icon=${ICONS[$cli]}
  cmd=${CMDS[$cli]}
  
  echo "  Starting $cli on port $port..."
  
  # Create tmux session
  tmux new-session -d -s "$cli" -c "$dir" 2>/dev/null || {
    echo "  ⚠️ tmux session $cli may already exist"
  }
  
  tmux send-keys -t "$cli" "clear" Enter
  tmux send-keys -t "$cli" "echo '$icon $cli CLI Workspace'" Enter
  tmux send-keys -t "$cli" "echo 'Directory: $dir'" Enter
  tmux send-keys -t "$cli" "echo ''" Enter
  tmux send-keys -t "$cli" "echo 'Type: $cmd  to start'" Enter
  
  # Start ttyd
  ttyd -p "$port" -W tmux attach-session -t "$cli" &
  
  sleep 0.5
done

# ============================================
# DONE
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       ✅ NodeBay Workspace Ready!                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Enabled CLIs:$ENABLED"
echo ""
echo "Ports:"
for cli in $ENABLED; do
  echo "  ${ICONS[$cli]} $cli: ${PORTS[$cli]}"
done
echo ""
echo "Access via: https://\$(hostname)-PORT.app.github.dev"
echo ""

# Keep alive
while true; do
  sleep 300
done
