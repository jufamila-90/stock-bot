#!/bin/bash
# scripts/deploy.sh
# Run on Local: Automates deployment to VM with strict verification
#
# Usage: ./scripts/deploy.sh

set -euo pipefail

# --- Configuration ---
# SSH Connection User (User with valid SSH key)
SSH_USER="juhyeon" 
# Target Service User (User running the bot)
VM_USER="jufamila"
VM_HOST="34.16.2.223"
REMOTE_DIR="/home/$VM_USER/stock-bot"
TMUX_SESSION="stock-bot"
SSH_KEY="~/.ssh/google_compute_engine"

# SSH Command Definition
# We connect as SSH_USER, but run commands as VM_USER using sudo
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$VM_HOST"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PC='\033[0;36m' # Primary Color
NC='\033[0m' # No Color

# Helper helper to run command as target user
run_remote() {
    local CMD="$1"
    $SSH_CMD "sudo -u $VM_USER bash -c '$CMD'"
}

log_step() {
    echo -e "${PC}==>${NC} $1"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo "========================================"
echo "🚀 Stock Bot Deployment System"
echo "   Target: $VM_USER@$VM_HOST"
echo "========================================"

# A. git check
if [ ! -d ".git" ]; then
    log_error "This script must be run from the repository root."
    exit 1
fi

# B. Branch check
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Current branch is '$CURRENT_BRANCH' (Expected: main)${NC}"
    echo "   Press any key to continue, or Ctrl+C to abort..."
    read -n 1 -s
fi

# Git status check
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes.${NC}"
    git status -s
    echo "   Deploying only committed code..."
fi

# C. Push
log_step "Pushing to origin/main..."
git push origin main

# D. Remote Execution
log_step "Connecting to VM for updates..."

# d-1. Pull
run_remote "cd $REMOTE_DIR && git pull --ff-only origin main"

# d-2. Venv setup
run_remote "cd $REMOTE_DIR && [ ! -d venv ] && python3 -m venv venv || true"

# d-3. Pip install
log_step "Updating dependencies..."
run_remote "cd $REMOTE_DIR && ./venv/bin/pip install -U pip && ./venv/bin/pip install -r requirements.txt"

# d-4. Verification (30s)
log_step "Running 30s verification test..."
# Ignoring timeout exit code (124)
run_remote "cd $REMOTE_DIR && timeout 30s ./venv/bin/python -u main.py > /tmp/bot_verify.log 2>&1 || [ \$? -eq 124 ]"

# Retrieve logs for analysis
log_step "Analyzing logs..."
LOG_CONTENT=$($SSH_CMD "sudo cat /tmp/bot_verify.log")

PASSED=0

# Success Checks
if echo "$LOG_CONTENT" | grep -q "✅ Gemini Model Initialized:"; then
    if echo "$LOG_CONTENT" | grep -E "✅ 구글 시트 연결 완료|✅ spreadsheet open OK|✅ SHEET_APPEND_OK"; then
        PASSED=1
    fi
fi

# Failure Checks
if echo "$LOG_CONTENT" | grep -E "404 models/|is not found for API version"; then
    log_error "Gemini Model 404 Error Detected"
    PASSED=0
fi
if echo "$LOG_CONTENT" | grep -q "403 Your API key was reported as leaked"; then
    log_error "Gemini API Key Leaked (403)"
    PASSED=0
fi
if echo "$LOG_CONTENT" | grep -q "No such file or directory: 'service_account.json'"; then
    log_error "Service Account JSON missing"
    PASSED=0
fi

if [ $PASSED -eq 1 ]; then
    log_success "Verification Passed!"
else
    log_error "Verification Failed! Last 120 lines:"
    echo "---------------------------------------------------"
    echo "$LOG_CONTENT" | tail -n 120
    echo "---------------------------------------------------"
    exit 1
fi

# E. Restart
log_step "Restarting Bot..."
run_remote "cd $REMOTE_DIR && ./scripts/restart_bot.sh"

log_success "Deployment Complete!!"
