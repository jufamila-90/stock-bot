#!/bin/bash
# scripts/restart_bot.sh
# Run on VM: Restarts the bot in a tmux session

SESSION="stock-bot"
cd "$(dirname "$0")/.." || exit 1

# 1. Stop existing session
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "🛑 Stopping existing tmux session: $SESSION"
    tmux kill-session -t "$SESSION"
    sleep 2
fi

# 2. Start new session
echo "🚀 Starting new tmux session: $SESSION"
# Create session detached, running main.py
# Using pipe to log file for persistence, but tmux itself also keeps history
tmux new-session -d -s "$SESSION" "./venv/bin/python -u main.py 2>&1 | tee bot.log"

# 3. Verify
sleep 2
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "✅ Bot started successfully in tmux session '$SESSION'"
    echo "   View logs: tmux attach -t $SESSION"
else
    echo "❌ Failed to start tmux session"
    exit 1
fi
