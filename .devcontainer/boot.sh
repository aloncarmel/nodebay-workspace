#!/bin/bash
# boot.sh - Runs on EVERY codespace start
# Sets up git repos, tmux sessions, ttyd instances, and ngrok tunnels
# Only starts CLIs that are ENABLED in the config

# Don't exit on error - we want to see what fails
set +e

# ============================================
# CONFIGURATION
# ============================================

# Find the workspace directory (it's the repo name)
WORKSPACE_DIR=$(find /workspaces -maxdepth 1 -type d -name "nodebay-*" 2>/dev/null | head -1)
if [ -z "$WORKSPACE_DIR" ]; then
  WORKSPACE_DIR=$(find /workspaces -maxdepth 1 -type d ! -name "." 2>/dev/null | head -1)
fi

NODEBAY_API="${NODEBAY_API:-https://nodebay.vercel.app}"
CODESPACE_NAME="${CODESPACE_NAME:-$(hostname)}"

# Log everything
exec > >(tee -a /tmp/boot.log) 2>&1

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       🚀 NodeBay Workspace Booting...                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "[$(date '+%H:%M:%S')] Workspace dir: $WORKSPACE_DIR"
echo "[$(date '+%H:%M:%S')] Codespace: $CODESPACE_NAME"
echo "[$(date '+%H:%M:%S')] API: $NODEBAY_API"

# Load workspace config (repos to clone per CLI)
if [ -f "$WORKSPACE_DIR/nodebay-config.json" ]; then
  CONFIG_FILE="$WORKSPACE_DIR/nodebay-config.json"
elif [ -f "$WORKSPACE_DIR/.devcontainer/workspace-config.json" ]; then
  CONFIG_FILE="$WORKSPACE_DIR/.devcontainer/workspace-config.json"
else
  CONFIG_FILE=""
fi

echo "[$(date '+%H:%M:%S')] Config file: $CONFIG_FILE"

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
# CHECK DEPENDENCIES
# ============================================

log "Checking dependencies..."

if ! command -v tmux &> /dev/null; then
  log "❌ tmux not found - installing..."
  sudo apt-get update && sudo apt-get install -y tmux
fi

if ! command -v jq &> /dev/null; then
  log "❌ jq not found - installing..."
  sudo apt-get update && sudo apt-get install -y jq
fi

if ! command -v ttyd &> /dev/null; then
  log "❌ ttyd not found - installing..."
  wget -q "https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64" -O /tmp/ttyd
  chmod +x /tmp/ttyd
  sudo mv /tmp/ttyd /usr/local/bin/ttyd
fi

if ! command -v ngrok &> /dev/null; then
  log "❌ ngrok not found - installing..."
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt-get update && sudo apt-get install -y ngrok
fi

log "✅ Dependencies OK"

# Ensure PATH includes Claude (if installed)
export PATH="$HOME/.claude/bin:$PATH"

# ============================================
# DETERMINE ENABLED CLIs
# ============================================

log "Checking enabled CLIs..."

if [ -f "$CONFIG_FILE" ]; then
  log "Config contents:"
  cat "$CONFIG_FILE"
fi

ENABLED_CLIS=""
for cli in claude codex gemini copilot; do
  if is_cli_enabled "$cli"; then
    ENABLED_CLIS="$ENABLED_CLIS $cli"
    log "  ✅ $cli is enabled"
  else
    log "  ⚪ $cli is disabled"
  fi
done

if [ -z "$ENABLED_CLIS" ]; then
  log ""
  log "⚠️  No CLIs enabled in config!"
  log "   Enable CLIs via NodeBay dashboard to start using them."
  log ""
  log "   Waiting for configuration... (check dashboard)"
  
  # Just sleep forever - don't exit, let the codespace stay alive
  while true; do
    sleep 60
    log "Still waiting for CLI to be enabled..."
    
    # Re-check config
    if [ -f "$CONFIG_FILE" ]; then
      for cli in claude codex gemini copilot; do
        if is_cli_enabled "$cli"; then
          log "CLI $cli was enabled! Restarting boot..."
          exec bash "$0"
        fi
      done
    fi
  done
fi

log ""
log "📋 Enabled CLIs:$ENABLED_CLIS"

# ============================================
# CREATE DEV DIRECTORIES
# ============================================

log ""
log "📂 Creating dev directories..."

for cli in $ENABLED_CLIS; do
  mkdir -p "$WORKSPACE_DIR/dev/$cli"
  log "  Created: $WORKSPACE_DIR/dev/$cli"
done

# ============================================
# KILL EXISTING PROCESSES
# ============================================

log ""
log "🧹 Cleaning up existing processes..."

pkill -f "ttyd" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
tmux kill-server 2>/dev/null || true

sleep 2
log "✅ Cleanup complete"

# ============================================
# CREATE TMUX SESSIONS
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
  
  tmux new-session -d -s "$cli" -c "$WORKSPACE_DIR/dev/$cli" || {
    log "  ⚠️ Failed to create tmux session for $cli"
    continue
  }
  
  tmux send-keys -t "$cli" "cd $WORKSPACE_DIR/dev/$cli && clear" Enter
  tmux send-keys -t "$cli" "echo '${CLI_NAMES[$cli]} Workspace'" Enter
  tmux send-keys -t "$cli" "echo 'Directory: $WORKSPACE_DIR/dev/$cli'" Enter
  tmux send-keys -t "$cli" "echo ''" Enter
  tmux send-keys -t "$cli" "echo 'Type: ${CLI_COMMANDS[$cli]}  to start the CLI'" Enter
done

log "✅ Tmux sessions created"

# ============================================
# START TTYD INSTANCES
# ============================================

log ""
log "🔌 Starting ttyd instances..."

declare -A CLI_PORTS=(
  ["claude"]=7681
  ["codex"]=7682
  ["gemini"]=7683
  ["copilot"]=7684
)

for cli in $ENABLED_CLIS; do
  port=${CLI_PORTS[$cli]}
  log "  Starting ttyd for $cli on port $port..."
  
  ttyd -p "$port" -W -t fontSize=14 -t theme='{"background":"#0c0c0c"}' \
    tmux attach-session -t "$cli" &
  
  sleep 1
  
  if lsof -i ":$port" > /dev/null 2>&1; then
    log "  ✅ $cli ttyd running on port $port"
  else
    log "  ⚠️ $cli ttyd may have failed to start on port $port"
  fi
done

log "✅ ttyd instances started"

# ============================================
# START NGROK TUNNELS
# ============================================

log ""
log "🌐 Starting ngrok tunnels..."

# Check if ngrok auth token is set
if [ -z "$NGROK_AUTHTOKEN" ]; then
  log "⚠️  NGROK_AUTHTOKEN not set!"
  log "   Set it in Codespace secrets or environment."
  log "   Tunnels will not work without it."
  log ""
  log "   To set: export NGROK_AUTHTOKEN=your_token"
  log "   Or add to Codespace secrets in repo settings."
else
  log "  NGROK_AUTHTOKEN is set"
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

log "  Ngrok config:"
cat /tmp/ngrok.yml

# Start tunnels
log "  Starting ngrok..."
ngrok start --all --config /tmp/ngrok.yml > /tmp/ngrok.log 2>&1 &

log "  Waiting for tunnels to establish..."
sleep 5

# ============================================
# ANNOUNCE URLS TO NODEBAY
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

if [ -z "$TUNNELS" ] || ! echo "$TUNNELS" | jq -e '.tunnels | length > 0' >/dev/null 2>&1; then
  log "❌ Failed to get tunnel URLs from ngrok"
  log "   Check /tmp/ngrok.log for details:"
  cat /tmp/ngrok.log 2>/dev/null | tail -20
else
  log "  Got tunnels from ngrok:"
  echo "$TUNNELS" | jq -r '.tunnels[] | "    \(.name): \(.public_url)"' 2>/dev/null

  for cli in $ENABLED_CLIS; do
    url=$(echo "$TUNNELS" | jq -r ".tunnels[] | select(.name==\"$cli\") | .public_url")
    
    if [ -n "$url" ] && [ "$url" != "null" ]; then
      log "  Announcing $cli: $url"
      
      # Announce to NodeBay API
      response=$(curl -s -X POST "$NODEBAY_API/api/announce" \
        -H "Content-Type: application/json" \
        -d "{\"codespace\": \"$CODESPACE_NAME:$cli\", \"url\": \"$url\"}" 2>&1)
      
      log "    Response: $response"
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
  echo "   $WORKSPACE_DIR/dev/$cli"
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
log "Logs at: /tmp/boot.log, /tmp/ngrok.log"

# Keep running
while true; do
  sleep 300
  log "Still running... ($(tmux list-sessions 2>/dev/null | wc -l) sessions active)"
done
