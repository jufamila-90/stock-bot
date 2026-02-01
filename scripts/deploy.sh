#!/bin/bash
# scripts/deploy.sh
# Run on Local: Automates deployment to VM

VM_HOST="34.16.2.223"
VM_USER="jufamila"
VM_DIR="/home/jufamila/stock-bot"
SSH_KEY="~/.ssh/google_compute_engine"
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $VM_USER@$VM_HOST"

echo "========================================"
echo "🚀 Stock Bot Deployment"
echo "========================================"

# 1. Local Git Push
echo "📦 Pushing local changes to GitHub..."
git push origin main || { echo "❌ Git push failed"; exit 1; }

# 2. Remote Update
echo "🔄 Updating code on VM..."
$SSH_CMD "cd $VM_DIR && git pull origin main" || { echo "❌ Remote git pull failed"; exit 1; }

# 3. Dependency Check
echo "📦 Checking dependencies..."
$SSH_CMD "cd $VM_DIR && ./venv/bin/python -m pip install -r requirements.txt" || { echo "❌ Pip install failed"; exit 1; }

# 4. Permissions (Ensure scripts are executable)
$SSH_CMD "chmod +x $VM_DIR/scripts/*.sh"

# 5. Verification Run (30s)
echo "🧪 Running verification (30s)..."
$SSH_CMD "cd $VM_DIR && timeout 30s ./venv/bin/python -u main.py > /tmp/bot_deploy_verify.log 2>&1"
VERIFY_EXIT=$?

# Analyze Verification Log
echo "🔍 Analyzing logs..."
LOG_CONTENT=$($SSH_CMD "cat /tmp/bot_deploy_verify.log")

# Check for critical success/error patterns
if echo "$LOG_CONTENT" | grep -q "Gemini Model Initialized"; then
    echo "   ✅ Gemini Initialized"
else
    echo "   ⚠️  Gemini Init NOT found (Check logs)"
fi

if echo "$LOG_CONTENT" | grep -q "Analyze Error" || echo "$LOG_CONTENT" | grep -q "Traceback"; then
    echo "   ❌ Critical Errors detected in logs:"
    echo "$LOG_CONTENT" | grep -E "Error|Traceback" | head -n 5
    echo "   ⚠️  Deployment Aborted due to verification failure."
    exit 1
fi

if [ $VERIFY_EXIT -eq 124 ]; then
    echo "   ✅ Verification passed (Timeout reached naturally)"
else
    echo "   ⚠️  Process exited early (Code: $VERIFY_EXIT)"
    echo "$LOG_CONTENT" | tail -n 10
fi

# 6. Restart Service
echo "🔄 Restarting Bot Service..."
$SSH_CMD "cd $VM_DIR && ./scripts/restart_bot.sh"

echo "========================================"
echo "✅ Deployment Complete!"
echo "   Monitor: $SSH_CMD 'tmux attach -t stock-bot'"
echo "========================================"
