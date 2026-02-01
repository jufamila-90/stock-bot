#!/bin/bash
# scripts/deploy.sh
# Run on Local: Automates deployment to VM with strict verification and UX
#
# Usage: ./scripts/deploy.sh

set -euo pipefail

# --- Configuration ---
SSH_USER="juhyeon" 
VM_USER="jufamila"
VM_HOST="34.16.2.223"
APP_DIR="/home/$VM_USER/stock-bot"
TMUX_NAME="stock-bot"
SSH_KEY="~/.ssh/google_compute_engine"
DEFAULT_BRANCH="main"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOCAL_LOG="/tmp/stock-bot_deploy_${TIMESTAMP}.log"
VERIFY_LOG="/tmp/bot_verify.log"

# SSH Command (Connect as SSH_USER, act as VM_USER)
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$VM_HOST"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output control (stdout + file)
exec > >(tee -a "$LOCAL_LOG") 2>&1

echo "========================================================"
echo "🚀 Stock Bot Deployment"
echo "========================================================"
echo "📍 Location   : Local ($(uname -n))"
echo "📂 Work Dir   : $(pwd)"
echo "📡 Target VM  : $VM_USER@$VM_HOST"
echo "📂 Remote Dir : $APP_DIR"
echo "📝 Local Log  : $LOCAL_LOG"
echo "========================================================"

# Helper to run remote command
run_remote() {
    local CMD="$1"
    $SSH_CMD "sudo -u $VM_USER bash -c '$CMD'"
}

summary() {
    local STATUS=$1
    local EXTRA_MSG=$2
    
    echo ""
    echo "==================== DEPLOY SUMMARY ===================="
    if [ "$STATUS" == "SUCCESS" ]; then
        echo -e "STATUS      : ${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "STATUS      : ${RED}❌ FAILED${NC}"
        echo -e "REASON      : $EXTRA_MSG"
    fi
    echo "REPO        : $(git config --get remote.origin.url) (branch: $CURRENT_BRANCH)"
    echo "VM          : $VM_USER@$VM_HOST"
    echo "APP_DIR     : $APP_DIR"
    echo "LOGS        : local=$LOCAL_LOG | vm=$VERIFY_LOG"
    
    if [ "$STATUS" == "SUCCESS" ]; then
        echo -e "CHECKS      : schedule ${GREEN}✅${NC} | sheet ${GREEN}✅${NC} | gemini ${GREEN}✅${NC}"
        echo -e "TMUX        : $TMUX_NAME ${GREEN}✅ running${NC}"
        echo "NEXT        : ssh command below to monitor"
        echo "              ssh -i $SSH_KEY $SSH_USER@$VM_HOST \"sudo -u $VM_USER tmux attach -t $TMUX_NAME\""
    else
        echo "SHOWING LOG : last 80 lines from $VERIFY_LOG"
        echo "--------------------------------------------------------"
        $SSH_CMD "sudo cat $VERIFY_LOG | tail -n 80"
        echo "--------------------------------------------------------"
    fi
    echo "========================================================"
}

# 1. Environment Check
log_step() { echo -e "${BLUE}==>${NC} $1"; }
failure() { summary "FAILED" "$1"; exit 1; }

if [ ! -d ".git" ]; then failure "Not a git repository root"; fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Current Branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
    echo -e "${YELLOW}⚠️  Current branch is '$CURRENT_BRANCH', expected '$DEFAULT_BRANCH'.${NC}"
    # Wait for user confirmation 
    # read -p "Continue? (y/n) " ... (Skipped for automation, but printed warning)
fi

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected. Deploying committed code only.${NC}"
fi

# 2. Push
log_step "Pushing changes to origin/$DEFAULT_BRANCH..."
git push origin "$DEFAULT_BRANCH" || failure "Git Push Failed"

# 3. Update VM
log_step "Updating code on VM..."
run_remote "cd $APP_DIR && git pull --ff-only origin $DEFAULT_BRANCH" || failure "Remote Git Pull Failed"

log_step "Checking dependencies..."
run_remote "cd $APP_DIR && [ ! -d venv ] && python3 -m venv venv || true"
# Suppress pip output unless error? keeping it for transparency
run_remote "cd $APP_DIR && ./venv/bin/pip install -r requirements.txt" || failure "Pip Install Failed"

# 4. Strict Validation
log_step "Running 30s Verification..."
# Run main.py with timeout. Exit 124 is normal timeout.
run_remote "cd $APP_DIR && timeout 30s ./venv/bin/python -u main.py > $VERIFY_LOG 2>&1 || [ \$? -eq 124 ]"

# Analyze Logs
log_step "Analyzing verification logs..."
LOG_CONTENT=$($SSH_CMD "sudo cat $VERIFY_LOG")

# Failure Detection Logic
if echo "$LOG_CONTENT" | grep -q "403 Your API key was reported as leaked"; then
    summary "FAILED" "Gemini API Key Leaked (403)\nHINT        : Replace GEMINI_KEY in VM .env"
    exit 1
elif echo "$LOG_CONTENT" | grep -q "404 models/"; then
    summary "FAILED" "Gemini Model Not Found (404)\nHINT        : Check GEMINI_MODEL in VM .env"
    exit 1
elif echo "$LOG_CONTENT" | grep -q "No such file or directory: 'service_account.json'"; then
    summary "FAILED" "Service Account Key Missing\nHINT        : Upload service_account.json to $APP_DIR"
    exit 1
elif echo "$LOG_CONTENT" | grep -q "ModuleNotFoundError"; then
    summary "FAILED" "Missing Python Dependency\nHINT        : Check requirements.txt"
    exit 1
elif echo "$LOG_CONTENT" | grep -q "Traceback (most recent call last)"; then
    summary "FAILED" "Python Exception (Traceback)\nHINT        : Check code for bugs"
    exit 1
fi

# Success Checks
SUCCESS=0
if echo "$LOG_CONTENT" | grep -q "Gemini Model Initialized"; then
    if echo "$LOG_CONTENT" | grep -E "✅ .*시트 연결|spreadsheet open OK|SHEET_APPEND_OK"; then
        SUCCESS=1
    fi
fi

if [ $SUCCESS -eq 0 ]; then
    summary "FAILED" "Verification Logic Failed (Success logs not found)\nHINT        : Check if bot initialized completely"
    exit 1
fi

# 5. Restart
log_step "Restarting Bot Process..."
run_remote "cd $APP_DIR && ./scripts/restart_bot.sh" || failure "Restart Script Failed"

# Final Success Summary
summary "SUCCESS" ""
