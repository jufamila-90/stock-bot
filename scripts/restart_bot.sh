#!/bin/bash
# scripts/restart_bot.sh
# Run on VM: Restarts the bot in a tmux session
# Usage: ./scripts/restart_bot.sh

set -euo pipefail

# Configuration
TMUX_SESSION="stock-bot"
cd "$(dirname "$0")/.." || { echo "❌ Cannot change directory to project root"; exit 1; }

echo "========================================"
echo "🔄 Bot Restart Process"
echo "========================================"

# b. Stop existing session
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "🛑 Stopping existing tmux session: $TMUX_SESSION"
    tmux kill-session -t "$TMUX_SESSION"
    sleep 2
fi

# c. Start new session
echo "🚀 Starting new tmux session: $TMUX_SESSION"
# Using pipe to log file for persistence
tmux new-session -d -s "$TMUX_SESSION" "./venv/bin/python -u main.py 2>&1 | tee bot.log"

# d. Verify session exists
echo "🔍 Checking session status..."
if tmux list-sessions | grep -q "$TMUX_SESSION"; then
    tmux list-sessions | grep "$TMUX_SESSION"
    echo "✅ Bot started successfully."
    echo "========================================"
    echo "e. To attach: tmux attach -t $TMUX_SESSION"
else
    echo "❌ Failed to start tmux session"
    exit 1
fi
