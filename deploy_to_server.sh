#!/bin/bash
# deploy_to_server.sh
# SSH 서버에 Stock Bot 배포

set -e  # 에러 발생 시 즉시 중단

# 설정
SERVER_USER="juhyeon"
SERVER_IP="34.16.2.223"
SSH_KEY="~/.ssh/google_compute_engine"
REMOTE_DIR="/home/juhyeon/stock-bot"

echo "========================================"
echo "Stock Bot 서버 배포 스크립트"
echo "========================================"
echo ""

# 1. 서버에 디렉토리 생성
echo "📁 서버에 프로젝트 디렉토리 생성 중..."
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_IP}" "mkdir -p ${REMOTE_DIR}"
echo "✅ 디렉토리 생성 완료: ${REMOTE_DIR}"
echo ""

# 2. 코드 파일 전송
echo "📤 코드 파일 전송 중..."
scp -i "${SSH_KEY}" \
    main.py \
    realtime_updater.py \
    add_ticker_columns.py \
    "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/"
echo "✅ 코드 파일 전송 완료"
echo ""

# 3. .env 파일 전송 (있는 경우)
if [ -f ".env" ]; then
    echo "📤 .env 파일 전송 중..."
    scp -i "${SSH_KEY}" .env "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/"
    echo "✅ .env 파일 전송 완료"
else
    echo "⚠️  .env 파일이 없습니다. .env.example을 참고하여 생성해주세요."
fi
echo ""

# 4. service_account.json 전송 (있는 경우)
if [ -f "service_account.json" ]; then
    echo "📤 service_account.json 전송 중..."
    scp -i "${SSH_KEY}" service_account.json "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/"
    echo "✅ service_account.json 전송 완료"
else
    echo "⚠️  service_account.json이 없습니다. Google API 인증 파일을 준비해주세요."
fi
echo ""

# 5. 서버에 백업 생성
echo "💾 서버에 백업 생성 중..."
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_IP}" \
    "cd ${REMOTE_DIR} && [ -f main.py ] && cp main.py main_backup_$(date +%Y%m%d_%H%M%S).py || true"
echo "✅ 백업 완료"
echo ""

# 6. Python 패키지 설치
echo "📦 Python 패키지 설치 중..."
ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_IP}" << 'ENDSSH'
cd /home/juhyeon/stock-bot

# Python 3 확인
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3가 설치되어 있지 않습니다."
    exit 1
fi

echo "✅ Python3 버전: $(python3 --version)"

# pip 설치 확인
if ! command -v pip3 &> /dev/null; then
    echo "⚠️  pip3 설치 중..."
    sudo apt-get update && sudo apt-get install -y python3-pip
fi

# 필요한 패키지 설치
echo "📦 필요한 패키지 설치 중..."
pip3 install --user pytz schedule feedparser requests pandas yfinance gspread google-generativeai python-dotenv FinanceDataReader oauth2client gspread-formatting

echo "✅ 패키지 설치 완료"
ENDSSH

echo "✅ 서버 환경 설정 완료"
echo ""

# 7. 봇 상태 확인
echo "🔍 봇 프로세스 확인 중..."
RUNNING=$(ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_IP}" "pgrep -f 'python3.*main.py' | wc -l" || echo "0")

if [ "$RUNNING" -gt 0 ]; then
    echo "⚠️  봇이 현재 실행 중입니다 (PID: $(ssh -i "${SSH_KEY}" "${SERVER_USER}@${SERVER_IP}" 'pgrep -f "python3.*main.py"'))"
    echo "   중지하려면: ssh -i ${SSH_KEY} ${SERVER_USER}@${SERVER_IP} 'pkill -f python3.*main.py'"
else
    echo "✅ 봇이 실행 중이지 않습니다"
fi
echo ""

echo "========================================"
echo "✅ 배포 완료!"
echo "========================================"
echo ""
echo "다음 명령어로 봇을 실행하세요:"
echo ""
echo "  ssh -i ${SSH_KEY} ${SERVER_USER}@${SERVER_IP}"
echo "  cd ${REMOTE_DIR}"
echo "  nohup python3 main.py > bot.log 2>&1 &"
echo ""
echo "로그 확인:"
echo "  tail -f ${REMOTE_DIR}/bot.log"
echo ""
echo "봇 중지:"
echo "  pkill -f 'python3.*main.py'"
echo ""
