#!/bin/bash
# scripts/restart_bot.sh
# Run on VM: Restarts the bot in a tmux session
# 
# Usage: ./scripts/restart_bot.sh

set -euo pipefail

# Configuration
TMUX_SESSION="stock-bot"
BOT_CMD="./venv/bin/python -u main.py"
# Ensure we are in the project root (parent directory of scripts/)
cd "$(dirname "$0")/.." || { echo "❌ Cannot change directory to project root"; exit 1; }

echo "========================================"
echo "🔄 Bot Restart Process"
echo "========================================"
echo "📍 Working Directory: $(pwd)"

# 1. Check/Stop existing session
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "🛑 Stopping existing tmux session: $TMUX_SESSION"
    tmux kill-session -t "$TMUX_SESSION"
    sleep 2
else
    echo "ℹ️  No active session found named '$TMUX_SESSION'"
fi

# 2. Start new session
echo "🚀 Starting new tmux session: $TMUX_SESSION"
# Create session detached, running main.py
# Using pipe to log file for persistence (logs also in tmux history)
tmux new-session -d -s "$TMUX_SESSION" "$BOT_CMD 2>&1 | tee bot.log"

# 3. Verify
sleep 2
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "✅ Bot started successfully in tmux session '$TMUX_SESSION'"
    echo "========================================"
    echo "📊 Process Info:"
    tmux list-sessions | grep "$TMUX_SESSION"
    echo "========================================"
    echo "👀 To view logs: tmux attach -t $TMUX_SESSION"
else
    echo "❌ Failed to start tmux session"
    exit 1
fi
