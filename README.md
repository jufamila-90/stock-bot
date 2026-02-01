# Stock Bot - Google Sheets 양방향 연동

구글 시트와 연동하여 매매 파라미터를 동적으로 관리하고, 실시간 매매 로그 및 주가/환율 데이터를 자동 갱신하는 Stock Trading Bot입니다.

## 주요 기능

### 1. 양방향 시트 연동
- **Ticker_Info 시트**: 컨트롤 타워로 사용
  - 매매 활성화 여부 (Active)
  - 종목별 목표 비중
  - 손절/익절 기준값
  - 봇이 시작할 때마다 자동으로 시트에서 읽어옴
  
- **주식거래_RAW 시트**: 실시간 매매 로깅
  - 매매 체결 시 자동으로 로그 기록
  - 거래일, 증권사, 계좌, 종목명, Ticker, 매매구분, 수량, 통화, 평단가 등
  - 한국 주식은 자동으로 `.KS` / `.KQ` 접두사 추가

### 2. 실시간 데이터 갱신
- **주가 시트**: 1분마다 모든 보유 종목의 현재가 업데이트
- **환율 시트**: 1분마다 USD/KRW 환율 업데이트

### 3. 손절/익절 자동화
- Ticker_Info 시트의 손절/익절 기준에 따라 자동 매도
- 종목별로 다른 손절/익절 기준 설정 가능

## 설치 및 설정

### 1. 필요한 패키지 설치

```bash
pip install pytz schedule feedparser requests pandas yfinance gspread google-generativeai python-dotenv FinanceDataReader oauth2client gspread-formatting
```

### 2. 환경 변수 설정

`.env.example`을 복사하여 `.env` 파일 생성:

```bash
cp .env.example .env
```

`.env` 파일을 열어서 다음 값들을 설정:

- `SPREADSHEET_ID`: 구글 시트 ID
- `KIS_APP_KEY`, `KIS_APP_SECRET`: KIS API 키
- `GEMINI_KEY`: Gemini AI API 키
- `TELEGRAM_TOKEN`, `CHAT_ID`: 텔레그램 알림 설정

### 3. Google Sheets API 인증

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트 생성
2. Google Sheets API 활성화
3. 서비스 계정 생성 및 JSON 키 다운로드
4. 다운로드한 JSON 파일을 `service_account.json`으로 저장
5. 구글 시트를 서비스 계정 이메일과 공유

### 4. Ticker_Info 시트 컬럼 추가

처음 실행 시 Ticker_Info 시트에 필요한 컬럼을 추가해야 합니다:

```bash
python3 add_ticker_columns.py
```

이 스크립트는 다음 컬럼을 추가합니다:
- **Active** (기본값: TRUE)
- **목표비중** (기본값: 10%)
- **손절기준** (기본값: -15%)
- **익절기준** (기본값: 30%)

## 실행 방법

### 로컬 실행

#### 1. 메인 봇 실행

```bash
python3 main.py
```

#### 2. 실시간 데이터 갱신 (별도 터미널)

주가와 환율을 1분마다 자동으로 갱신합니다:

```bash
python3 realtime_updater.py
```

### 서버 배포

SSH 서버에 배포하려면:

```bash
./deploy_to_server.sh
```

배포 후 서버에 접속하여 봇 실행:

```bash
ssh -i ~/.ssh/google_compute_engine juhyeon@34.16.2.223
cd /home/juhyeon/stock-bot

# 백그라운드 실행
nohup python3 main.py > bot.log 2>&1 &
nohup python3 realtime_updater.py > updater.log 2>&1 &

# 로그 확인
tail -f bot.log
tail -f updater.log
```

## 구글 시트 구조

### Ticker_Info (컨트롤 타워)

| 시장 | 섹터 | Ticker | 종목명 | Active | 목표비중 | 손절기준 | 익절기준 |
|------|------|--------|--------|--------|---------|---------|---------|
| 한국(코스피) | 반도체 | 000660 | SK하이닉스 | TRUE | 15% | -10% | 25% |
| 미국 | 기술 | AAPL | Apple Inc. | TRUE | 20% | -12% | 30% |
| 한국(코스닥) | 바이오 | 096530 | 셀트리온제약 | FALSE | 5% | -15% | 40% |

### 주식거래_RAW (매매 로그)

| 거래일 | 증권사 | 계좌 | 종목명 | Ticker | 매매구분 | 수량 | 통화 | 평단가 | 금액 |
|--------|--------|------|--------|--------|---------|------|------|--------|------|
| 2026-01-20 | KIS | KIS01 | SK하이닉스 | 000660.KS | 매수 | 10 | KRW | 125000 | 1250000 |
| 2026-01-20 | KIS | KIS01 | Apple Inc. | AAPL | 매수 | 5 | USD | 180.50 | 1306625 |

### 주가 (실시간 갱신)

| Ticker | 현재가 | 전일대비 | 등락률(%) | 업데이트시간 |
|--------|--------|---------|----------|--------------|
| 000660.KS | 126500 | +1500 | +1.20 | 2026-01-20 14:35:22 |
| AAPL | 182.30 | +1.80 | +1.00 | 2026-01-20 14:35:22 |

### 환율 (실시간 갱신)

| 통화쌍 | 환율 | 업데이트시간 |
|--------|------|--------------|
| USD/KRW | 1445.50 | 2026-01-20 14:35:22 |

## 트러블슈팅

### service_account.json 오류
- 파일이 프로젝트 디렉토리에 있는지 확인
- JSON 파일 형식이 올바른지 확인 (Google Cloud Console에서 다운로드)

### 시트 권한 오류
- 구글 시트를 서비스 계정 이메일과 공유했는지 확인
- 편집 권한이 있는지 확인

### Ticker_Info 로딩 실패
- `Ticker`와 `종목명` 컬럼이 있는지 확인
- `add_ticker_columns.py`를 실행하여 필수 컬럼 추가

### 환율/주가 조회 실패
- 인터넷 연결 확인
- yfinance 패키지가 정상 설치되었는지 확인

## 파일 구조

```
stock-bot/
├── main.py                  # 메인 봇 (매매 로직)
├── realtime_updater.py      # 실시간 데이터 갱신
├── add_ticker_columns.py    # Ticker_Info 컬럼 추가 도구
├── deploy_to_server.sh      # 서버 배포 스크립트
├── .env                     # 환경 변수 (비공개)
├── .env.example             # 환경 변수 예시
├── service_account.json     # Google API 인증 (비공개)
├── bot_state.json           # 봇 상태 저장 (자동 생성)
└── README.md                # 이 파일
```

## 주요 업데이트 (v33.1 → 양방향 연동)

### 추가된 기능
- ✅ Ticker_Info 시트에서 매매 파라미터 동적 로딩
- ✅ 주식거래_RAW 시트에 실시간 매매 로그 기록
- ✅ 한국 주식 티커에 `.KS`/`.KQ` 자동 추가
- ✅ 주가/환율 실시간 갱신 (1분 주기)
- ✅ 종목별 손절/익절 기준 커스터마이징
- ✅ 서버 배포 자동화 스크립트

### 변경된 동작
- 하드코딩된 매매 파라미터 → 시트 기반 동적 설정
- 고정 손절/익절 비율 → 종목별 커스터마이징 가능
- 수동 로그 기록 → 자동 로그 기록 (시트 연동)

## 라이선스

MIT License

## 문의

문제가 발생하거나 질문이 있으면 이슈를 생성해주세요.

