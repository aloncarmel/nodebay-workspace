#!/bin/bash
# agent.sh - Watches git repo for config changes and auto-applies them

WORKSPACE_DIR=$(find /workspaces -maxdepth 1 -type d -name "nodebay-*" 2>/dev/null | head -1)
CONFIG_FILE="$WORKSPACE_DIR/nodebay-config.json"
LAST_HASH=""
POLL_INTERVAL=5

echo "[Agent] Starting NodeBay agent..."
echo "[Agent] Workspace: $WORKSPACE_DIR"
echo "[Agent] Polling every ${POLL_INTERVAL}s for config changes"

cd "$WORKSPACE_DIR" || exit 1

while true; do
  # Fetch latest from remote
  git fetch origin main --quiet 2>/dev/null
  
  # Check if local is behind remote
  LOCAL=$(git rev-parse HEAD 2>/dev/null)
  REMOTE=$(git rev-parse origin/main 2>/dev/null)
  
  if [ "$LOCAL" != "$REMOTE" ]; then
    echo "[Agent] $(date '+%H:%M:%S') Config changed! Pulling updates..."
    
    # Pull latest
    git pull origin main --quiet 2>/dev/null
    
    # Kill existing ttyd processes
    pkill -f ttyd 2>/dev/null || true
    tmux kill-server 2>/dev/null || true
    
    echo "[Agent] Running boot.sh..."
    bash .devcontainer/boot.sh &
    
    echo "[Agent] Update complete!"
  fi
  
  sleep $POLL_INTERVAL
done

