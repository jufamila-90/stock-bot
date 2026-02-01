#!/bin/bash
# scripts/restart_bot.sh
# Run on VM: Restarts the bot in a tmux session with log rotation
# Usage: ./scripts/restart_bot.sh

set -euo pipefail

# Configuration
TMUX_SESSION="stock-bot"
LOG_FILE="bot.log"
cd "$(dirname "$0")/.." || { echo "❌ Cannot cd to project root"; exit 1; }

echo "========================================"
echo "🔄 Bot Restart Process (VM)"
echo "========================================"

# 1. Log Rotation
if [ -f "$LOG_FILE" ]; then
    echo "📦 Rotating logs..."
    for i in 4 3 2 1; do
        if [ -f "${LOG_FILE}.$i" ]; then
            mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        fi
    done
    mv "$LOG_FILE" "${LOG_FILE}.1"
fi

# 2. Stop Existing Session
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "🛑 Stopping existing tmux session: $TMUX_SESSION"
    tmux kill-session -t "$TMUX_SESSION"
    sleep 2
else
    echo "ℹ️  No active session found."
fi

# 3. Start New Session
echo "🚀 Starting new tmux session: $TMUX_SESSION"
# Use pipe to tee to write to bot.log
tmux new-session -d -s "$TMUX_SESSION" "./venv/bin/python -u main.py 2>&1 | tee -a $LOG_FILE"

# 4. Verify
sleep 2
if tmux list-sessions | grep -q "$TMUX_SESSION"; then
    echo "✅ Bot started successfully."
    echo "   Session: $(tmux list-sessions | grep $TMUX_SESSION)"
else
    echo "❌ Failed to start tmux session"
    exit 1
fi
