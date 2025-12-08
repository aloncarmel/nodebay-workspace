#!/bin/bash
# boot.sh - Runs on EVERY codespace start
# Sets up git repos, tmux sessions, ttyd instances, and ngrok tunnels
# Only starts CLIs that are ENABLED in the config

set -e

# ============================================
# CONFIGURATION
# ============================================

NODEBAY_API="https://57325b28d992.ngrok-free.app"
CODESPACE_NAME="${CODESPACE_NAME:-$(hostname)}"

# Load workspace config (repos to clone per CLI)
# First check for user-pushed config, then fall back to template default
if [ -f "/workspaces/nodebay-config.json" ]; then
  CONFIG_FILE="/workspaces/nodebay-config.json"
elif [ -f "/workspaces/.devcontainer/workspace-config.json" ]; then
  CONFIG_FILE="/workspaces/.devcontainer/workspace-config.json"
else
  CONFIG_FILE=""
fi

# ============================================
# HELPER FUNCTIONS
# ============================================

log() {
  echo "[$(date '+%H:%M:%S')] $1"
}

get_config_value() {
  local cli=$1
  local key=$2
  local default=$3
  
  if [ -f "$CONFIG_FILE" ]; then
    value=$(jq -r ".$cli.$key // empty" "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$value" ] && [ "$value" != "null" ]; then
      echo "$value"
      return
    fi
  fi
  echo "$default"
}

is_cli_enabled() {
  local cli=$1
  local enabled=$(get_config_value "$cli" "enabled" "false")
  [ "$enabled" = "true" ]
}

# ============================================
# START
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       🚀 NodeBay Workspace Booting...                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log "Codespace: $CODESPACE_NAME"
log "API: $NODEBAY_API"
log "Config: $CONFIG_FILE"

# Ensure PATH includes Claude
export PATH="$HOME/.claude/bin:$PATH"

# Determine which CLIs are enabled
ENABLED_CLIS=""
for cli in claude codex gemini copilot; do
  if is_cli_enabled "$cli"; then
    ENABLED_CLIS="$ENABLED_CLIS $cli"
  fi
done

if [ -z "$ENABLED_CLIS" ]; then
  log ""
  log "⚠️  No CLIs enabled in config!"
  log "   Enable CLIs via NodeBay dashboard to start using them."
  log ""
  log "   Config file: $CONFIG_FILE"
  
  # Just keep the script alive and wait for rebuild
  log "Waiting for configuration..."
  sleep infinity
fi

log ""
log "📋 Enabled CLIs:$ENABLED_CLIS"

# ============================================
# 1. GIT CLONE/PULL REPOS (only for enabled CLIs)
# ============================================

log ""
log "📂 Setting up dev directories with git repos..."

setup_repo() {
  local cli=$1
  local dir="/workspaces/dev/$cli"
  local repo_url=$(get_config_value "$cli" "repo" "")
  local branch=$(get_config_value "$cli" "branch" "main")
  
  mkdir -p "$dir"
  cd "$dir"
  
  if [ -d ".git" ]; then
    log "  [$cli] Pulling latest from $branch..."
    git fetch origin 2>/dev/null || true
    git checkout "$branch" 2>/dev/null || true
    git pull origin "$branch" 2>/dev/null || log "  [$cli] Pull failed (might have local changes)"
  elif [ -n "$repo_url" ] && [ "$repo_url" != "null" ] && [ "$repo_url" != "" ]; then
    log "  [$cli] Cloning $repo_url..."
    git clone --branch "$branch" "$repo_url" . 2>/dev/null || {
      log "  [$cli] Clone failed, initializing empty repo"
      git init
    }
  else
    log "  [$cli] No repo configured, initializing empty"
    [ ! -d ".git" ] && git init
  fi
}

for cli in $ENABLED_CLIS; do
  setup_repo "$cli"
done

log "✅ Git repos ready"

# ============================================
# 2. KILL EXISTING PROCESSES
# ============================================

log ""
log "🧹 Cleaning up existing processes..."

pkill -f "ttyd" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
tmux kill-server 2>/dev/null || true

sleep 2
log "✅ Cleanup complete"

# ============================================
# 3. CREATE TMUX SESSIONS (only for enabled CLIs)
# ============================================

log ""
log "🖥️  Creating tmux sessions..."

# CLI display names and commands
declare -A CLI_NAMES=(
  ["claude"]="🤖 Claude CLI"
  ["codex"]="🧠 Codex CLI"
  ["gemini"]="✨ Gemini CLI"
  ["copilot"]="🐙 GitHub Copilot CLI"
)

declare -A CLI_COMMANDS=(
  ["claude"]="claude"
  ["codex"]="codex"
  ["gemini"]="gemini"
  ["copilot"]="github-copilot-cli"
)

for cli in $ENABLED_CLIS; do
  log "  Creating session: $cli"
  
  tmux new-session -d -s "$cli" -c "/workspaces/dev/$cli"
  tmux send-keys -t "$cli" "cd /workspaces/dev/$cli && clear" Enter
  tmux send-keys -t "$cli" "echo '${CLI_NAMES[$cli]} Workspace'" Enter
  tmux send-keys -t "$cli" "echo 'Directory: /workspaces/dev/$cli'" Enter
  tmux send-keys -t "$cli" "echo ''" Enter
  tmux send-keys -t "$cli" "echo 'Type: ${CLI_COMMANDS[$cli]}  to start the CLI'" Enter
done

log "✅ Tmux sessions created"

# ============================================
# 4. START TTYD INSTANCES (only for enabled CLIs)
# ============================================

log ""
log "🔌 Starting ttyd instances..."

# Port mapping
declare -A CLI_PORTS=(
  ["claude"]=7681
  ["codex"]=7682
  ["gemini"]=7683
  ["copilot"]=7684
)

for cli in $ENABLED_CLIS; do
  port=${CLI_PORTS[$cli]}
  log "  $cli ttyd on port $port"
  
  ttyd -p "$port" -W -t fontSize=14 -t theme='{"background":"#0c0c0c"}' \
    tmux attach-session -t "$cli" &
done

sleep 2
log "✅ ttyd instances running"

# ============================================
# 5. START NGROK TUNNELS (only for enabled CLIs)
# ============================================

log ""
log "🌐 Starting ngrok tunnels..."

# Check if ngrok auth token is set
if [ -z "$NGROK_AUTHTOKEN" ]; then
  log "⚠️  NGROK_AUTHTOKEN not set! Tunnels will not work."
  log "   Set it in Codespace secrets."
else
  # Configure ngrok
  ngrok config add-authtoken "$NGROK_AUTHTOKEN" 2>/dev/null || true
fi

# Create ngrok config for enabled tunnels only
cat > /tmp/ngrok.yml << EOF
version: "2"
tunnels:
EOF

for cli in $ENABLED_CLIS; do
  port=${CLI_PORTS[$cli]}
  cat >> /tmp/ngrok.yml << EOF
  $cli:
    addr: $port
    proto: http
EOF
done

# Start tunnels
ngrok start --all --config /tmp/ngrok.yml > /tmp/ngrok.log 2>&1 &

log "  Waiting for tunnels to establish..."
sleep 5

# ============================================
# 6. ANNOUNCE URLS TO NODEBAY
# ============================================

log ""
log "📡 Announcing tunnel URLs to NodeBay..."

# Get all tunnel info from ngrok API
TUNNELS=""
for i in {1..10}; do
  TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)
  if [ -n "$TUNNELS" ] && echo "$TUNNELS" | jq -e '.tunnels | length > 0' >/dev/null 2>&1; then
    break
  fi
  log "  Waiting for ngrok API... (attempt $i)"
  sleep 2
done

if [ -z "$TUNNELS" ]; then
  log "❌ Failed to get tunnel URLs from ngrok"
  log "   Check /tmp/ngrok.log for details"
else
  for cli in $ENABLED_CLIS; do
    url=$(echo "$TUNNELS" | jq -r ".tunnels[] | select(.name==\"$cli\") | .public_url")
    
    if [ -n "$url" ] && [ "$url" != "null" ]; then
      log "  $cli: $url"
      
      # Announce to NodeBay API
      curl -s -X POST "$NODEBAY_API/api/announce" \
        -H "Content-Type: application/json" \
        -d "{\"codespace\": \"$CODESPACE_NAME:$cli\", \"url\": \"$url\"}" \
        > /dev/null 2>&1 || log "  ⚠️  Failed to announce $cli"
    else
      log "  ⚠️  No tunnel URL for $cli"
    fi
  done
  
  log "✅ URLs announced to NodeBay"
fi

# ============================================
# DONE!
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       ✅ NodeBay Workspace Ready!                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Enabled CLIs:$ENABLED_CLIS"
echo ""
echo "📂 Dev Directories:"
for cli in $ENABLED_CLIS; do
  echo "   /workspaces/dev/$cli"
done
echo ""
echo "🔗 Tunnel URLs:"
if [ -n "$TUNNELS" ]; then
  echo "$TUNNELS" | jq -r '.tunnels[] | "   \(.name): \(.public_url)"' 2>/dev/null || echo "   (check /tmp/ngrok.log)"
else
  echo "   (check /tmp/ngrok.log)"
fi
echo ""
echo "🖥️  Tmux Sessions:"
for cli in $ENABLED_CLIS; do
  echo "   tmux attach -t $cli"
done
echo ""

# Keep script alive to maintain processes
log "Boot complete. Keeping processes alive..."
wait
