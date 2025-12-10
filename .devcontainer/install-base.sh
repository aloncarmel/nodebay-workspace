#!/bin/bash
# install-base.sh - Minimal setup, runs once on container creation

echo "NodeBay: Installing base tools..."

sudo apt-get update -qq
sudo apt-get install -y -qq tmux jq curl wget lsof

# Install ttyd for terminal
wget -q "https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64" -O /tmp/ttyd
chmod +x /tmp/ttyd
sudo mv /tmp/ttyd /usr/local/bin/ttyd

echo "NodeBay: Base setup complete!"
