# Stock Bot Runbook

## 1. 개요
이 문서는 Stock Bot (V33+)의 설치, 실행, 문제 해결 방법을 다룹니다.

## 2. 최초 설치 및 실행
### 필수 요건
- Python 3.9+ (Python 3.11 권장)
- Git

### 설치 (Mac/Linux)
```bash
# 1. 레포지토리 클론 (이미 했다면 생략)
git clone https://github.com/jufamila-90/stock-bot.git
cd stock-bot

# 2. 가상환경 생성 및 의존성 설치 (자동)
# 이미 venv가 있다면 재사용합니다.
python3 -m venv venv
./venv/bin/python -m pip install -U pip
./venv/bin/python -m pip install -r requirements.txt
```

### 실행 (Local/Server)
```bash
# 기본 실행
./venv/bin/python -u main.py

# 백그라운드 실행 (서버)
nohup ./venv/bin/python -u main.py > bot.log 2>&1 &
tail -f bot.log
```

## 3. 환경 변수 설정 (.env)
`.env` 파일은 절대 커밋하면 안 됩니다. `.env.example`이 있다면 복사해서 사용하세요. 없으면 아래 형식을 따릅니다.

1. `.env` 파일 생성: `touch .env`
2. 내용 작성 (예시):
```ini
# --- TELEGRAM ---
TELEGRAM_TOKEN=123456:ABC-DEF...
CHAT_ID=12345678

# --- GOOGLE SHEET ---
# service_account.json 파일이 프로젝트 루트에 잇어야 합니다.
SPREADSHEET_ID=1A2B3C... (URL의 /d/ 와 /edit 사이의 ID)
SHEET_HEARTBEAT_SEC=180

# --- GEMINI (Optional) ---
GEMINI_KEY=AIzaSy...
GEMINI_MODEL=gemini-2.5-flash  # (Optional) Defaults to gemini-2.5-flash

# --- KIS (한국투자증권) ---
KIS_APP_KEY=...
KIS_APP_SECRET=...
KIS_CANO=12345678
KIS_ACNT_PRDT_CD=01
KIS_ENV=VIRTUAL  # 또는 REAL
```

## 4. 민감 파일 관리 규칙 (보안)
다음 파일들은 **절대** Git에 커밋하지 마세요.
- `.env` (API 키, 비밀번호)
- `service_account.json` (구글 인증 키)
- `bot_state.json` (로컬 상태 저장소)
- `*.log` (로그 파일)
- `venv/` (가상환경)

`.gitignore`에 등록되어 있는지 항상 확인하세요.

## 5. 자주 발생하는 에러 (Troubleshooting)

### Q: `ModuleNotFoundError: No module named 'schedule'`
**A:** 가상환경이 활성화되지 않았거나 패키지가 설치되지 않았습니다.
```bash
# 해결
./venv/bin/python -m pip install -r requirements.txt
```

### Q: `gspread.exceptions.APIError` (403 or 500)
**A:** `service_account.json` 파일이 없거나, 해당 서비스 계정 이메일이 구글 시트에 "편집자"로 초대되지 않았습니다.
1. `service_account.json` 내 `client_email` 확인.
2. 구글 시트 우상단 '공유' 버튼 -> 해당 이메일 추가.

### Q: KIS API 오류 (토큰 만료 등)
**A:** `bot_state.json`을 삭제하고 재시작하면 토큰을 새로 발급받습니다.
```bash
rm bot_state.json
./venv/bin/python main.py
```

## 6. 자동화 배포

`scripts/deploy.sh`를 사용하면 코드 푸시, VM 업데이트, 실행 검증, 재시작이 한 번에 처리됩니다.

### 사용법
1. 로컬에서 코드 수정 후 git commit
2. `./scripts/deploy.sh` 실행
3. VM에서 확인: `tmux attach -t stock-bot`

### 구성 요소
- **scripts/deploy.sh**: 로컬에서 실행. Git 동기화, VM 업데이트, 검증 실행, 자동 재시작을 조율.
- **scripts/restart_bot.sh**: VM 내에서 실행. 안정적인 백그라운드 프로세스 관리(`stock-bot` tmux 세션).

### 검증 로직
배포 스크립트는 30초간 봇을 실행하여 다음 항목을 자동 검사합니다:
- ✅ Gemini 모델 초기화
- ✅ 구글 시트 연결 성공
- ❌ 404/403 모델 에러 유무

**[주의] VM의 .env에 등록된 API 키가 유효한지 주기적으로 확인해주세요 (로그에 403 에러가 뜨면 키 교체 필요).**

### 실패 시 확인법
배포가 실패하면 스크립트가 로그 마지막 120줄을 출력합니다. 전체 로그 확인이 필요하면:
```bash
ssh -i ~/.ssh/google_compute_engine juhyeon@34.16.2.223 "sudo cat /tmp/bot_verify.log"
```
