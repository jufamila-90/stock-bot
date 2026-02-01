#!/bin/bash
# scripts/deploy.sh
# Run on Local Check: Automates deployment to VM
#
# Usage: ./scripts/deploy.sh

set -euo pipefail

# --- Configuration ---
VM_HOST="34.16.2.223"
VM_USER="juhyeon"          # SSH connection user (key registered)
TARGET_USER="jufamila"     # Actual bot execution user
REMOTE_DIR="/home/$TARGET_USER/stock-bot"
TMUX_SESSION="stock-bot"
SSH_KEY="~/.ssh/google_compute_engine"
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $VM_USER@$VM_HOST"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PC='\033[0;36m' # Primary Color
NC='\033[0m' # No Color

# Helper to run command as target user
run_as_target() {
    local CMD="$1"
    # Execute as target user using sudo
    $SSH_CMD "sudo -u $TARGET_USER bash -c '$CMD'"
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
echo "🚀 Stock Bot Deployment"
echo "   Target: $TARGET_USER@$VM_HOST ($REMOTE_DIR)"
echo "========================================"

# 1. Local Git Check
log_step "Checking local repository status..."
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Current branch is '$BRANCH', not 'main'.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Aborted by user."
        exit 1
    fi
fi

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes.${NC}"
    # By default continue, but warn
    git status -s
    echo "   (Deploying only committed code)"
fi

log_step "Pushing changes to origin/main..."
git push origin main || { log_error "Git push failed"; exit 1; }

# 2. Remote Update
log_step "Updating code on VM..."
run_as_target "cd $REMOTE_DIR && git pull --ff-only origin main" || { log_error "Remote git pull failed"; exit 1; }

# 3. Dependency Check
log_step "Checking dependencies (venv & pip)..."
run_as_target "cd $REMOTE_DIR && [ ! -d venv ] && python3 -m venv venv || true"
run_as_target "cd $REMOTE_DIR && ./venv/bin/python -m pip install -r requirements.txt" || { log_error "Pip install failed"; exit 1; }

# 4. Permissions
log_step "Updating script permissions..."
run_as_target "chmod +x $REMOTE_DIR/scripts/*.sh"

# 5. Verification Run (30s)
log_step "Running 30s Verification Test..."
# Ignore exit code 124 (timeout) but fail on others
run_as_target "cd $REMOTE_DIR && timeout 30s ./venv/bin/python -u main.py > /tmp/bot_deploy_verify.log 2>&1 || [ \$? -eq 124 ]"

# Analyze Log
log_step "Analyzing verification logs..."
LOG_CONTENT=$($SSH_CMD "sudo cat /tmp/bot_deploy_verify.log")

FAILED=0

# Critical Checks
if echo "$LOG_CONTENT" | grep -q "Gemini Model Initialized"; then
    log_success "Gemini Verified"
else
    log_error "Gemini Init NOT found"
    FAILED=1
fi

if echo "$LOG_CONTENT" | grep -E "✅ .*시트 연결|✅ spreadsheet open OK|✅ 구글 시트 연결 완료"; then
    log_success "Google Sheet Connected"
else
    log_error "Google Sheet Connection NOT found"
    FAILED=1
fi

if echo "$LOG_CONTENT" | grep -q "404 models/"; then
    log_error "Model 404 Error Detected"
    FAILED=1
fi

if echo "$LOG_CONTENT" | grep -q "403 Your API key was reported as leaked"; then
    log_error "API Key Leaked (403) Error Detected"
    FAILED=1
fi

if [ $FAILED -eq 1 ]; then
    log_error "Deploy Verification FAILED. Last 80 lines of log:"
    echo "---------------------------------------------------"
    echo "$LOG_CONTENT" | tail -n 80
    echo "---------------------------------------------------"
    exit 1
fi

log_success "Verification Passed!"

# 6. Restart Service
log_step "Restarting Bot Service..."
run_as_target "cd $REMOTE_DIR && ./scripts/restart_bot.sh"

echo "========================================"
log_success "Deployment Complete Success!"
echo "   Monitor: $SSH_CMD 'sudo -u $TARGET_USER tmux attach -t $TMUX_SESSION'"
echo "========================================"
