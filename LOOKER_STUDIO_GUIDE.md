# Looker Studio 연동 가이드 (Stock Bot)

이 가이드는 `Looker_Data` 시트 데이터를 사용하여 [Looker Studio](https://lookerstudio.google.com/)에서 주식 투자 대시보드를 만드는 방법을 설명합니다.

## 1. 사전 준비
- **구글 시트 확인**: 봇이 실행된 후 구글 시트에 `Looker_Data` 탭이 생성되었는지 확인하세요.
- **데이터 확인**: `Looker_Data` 탭에 헤더(`Date`, `Ticker`, `Name`...)와 데이터가 있어야 합니다.

## 2. 데이터 소스 연결
1. [Looker Studio](https://lookerstudio.google.com/) 접속 및 로그인.
2. **만들기** (+) -> **데이터 소스** 선택.
3. **Google Sheets** 커넥터 선택.
4. **스프레드시트** 선택 -> **워크시트**에서 `Looker_Data` 선택.
5. "첫 번째 행을 헤더로 사용" 체크 확인 -> **연결** 클릭.

## 3. 필드 타입 설정 (중요)
데이터 소스 화면에서 필드 타입을 아래와 같이 설정하세요.

| 필드명 | 타입 | 집계 방식 |
|---|---|---|
| Date | 날짜 및 시간 (YYYY-MM-DD HH:mm:ss) | 없음 |
| Ticker | 텍스트 | 없음 |
| Qty | 숫자 | 합계 |
| AvgPrice, CurPrice | 통화 (KRW) | 평균 |
| MarketValue | 통화 (KRW) | 합계 |
| PnL | 통화 (KRW) | 합계 |
| PnL_Pct | 퍼센트 (%) | 평균 |
| Market | 텍스트 | 없음 |

**팁**: `PnL_Pct` 같은 비율은 단순 평균하면 왜곡될 수 있습니다. 정확한 포트폴리오 수익률을 보려면 새 계산 필드를 만드세요:
- 이름: `Portfolio_Yield`
- 수식: `SUM(PnL) / SUM(MarketValue - PnL)`

## 4. 리포트 구성 (추천 템플릿)

### A. 요약 스코어카드 (상단)
- **총 평가금액**: 측정항목 `MarketValue` (집계: 합계)
- **총 손익**: 측정항목 `PnL` (집계: 합계)
- **보유 종목 수**: 측정항목 `Ticker` (집계: 카운트(고유))

### B. 보유 종목 테이블 (중앙)
- **차원**: `Name`, `Ticker`, `Market`
- **측정항목**: `Qty`, `AvgPrice`, `CurPrice`, `PnL`, `PnL_Pct`
- **정렬**: `PnL` 내림차순 (수익 높은 순)

### C. 국가별 비중 (파이 차트)
- **차원**: `Market`
- **측정항목**: `MarketValue`

## 5. 자동 업데이트 설정
- 봇(`main.py`)이 매 사이클(약 3분)마다 `Looker_Data` 시트를 갱신합니다.
- Looker Studio 리포트 상단의 "데이터 새로고침"을 누르면 최신 상태가 반영됩니다.
- (참고) Looker Studio는 기본적으로 15분~1시간 주기로 데이터를 캐싱합니다.

## 6. 문제 해결
- **데이터가 안 보임**: 봇이 한 번이라도 실행되어 포트폴리오 데이터를 기록했는지 확인하세요. 포트폴리오가 비어있으면 데이터가 없을 수 있습니다.
- **차트 에러**: 필드 타입이 '텍스트'로 되어 있지 않은지 확인하세요 (특히 숫자 필드).
