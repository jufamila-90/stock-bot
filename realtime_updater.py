#!/usr/bin/env python3
"""
realtime_updater.py
주가와 환율 데이터를 1분마다 구글 시트에 업데이트하는 백그라운드 스크립트
"""

import os
import time
import datetime
import schedule
import yfinance as yf
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from dotenv import load_dotenv

# .env 로드
load_dotenv()

SERVICE_ACCOUNT_FILE = "service_account.json"
SPREADSHEET_ID = os.getenv("SPREADSHEET_ID", "")

# 전역 변수
GSHEET = None


def initialize_sheet():
    """구글 시트 연결"""
    global GSHEET
    try:
        scope = [
            "https://spreadsheets.google.com/feeds",
            "https://www.googleapis.com/auth/drive",
        ]
        creds = ServiceAccountCredentials.from_json_keyfile_name(SERVICE_ACCOUNT_FILE, scope)
        client = gspread.authorize(creds)
        
        if SPREADSHEET_ID:
            GSHEET = client.open_by_key(SPREADSHEET_ID)
        else:
            raise ValueError("SPREADSHEET_ID가 설정되지 않았습니다")
        
        print(f"✅ 구글 시트 연결 완료: {SPREADSHEET_ID}")
    except Exception as e:
        GSHEET = None
        print(f"⚠️ 시트 연결 실패: {e}")


def update_stock_prices():
    """
    Ticker_Info 시트에서 모든 ticker를 읽어서
    주가 시트에 현재가를 업데이트
    """
    if not GSHEET:
        print("⚠️ 시트 연결 안 됨")
        return
    
    try:
        # Ticker_Info 읽기
        ticker_ws = GSHEET.worksheet("Ticker_Info")
        all_data = ticker_ws.get_all_values()
        
        if not all_data or len(all_data) < 2:
            print("⚠️ Ticker_Info 시트가 비어있습니다")
            return
        
        headers = all_data[0]
        ticker_idx = headers.index("YahooFinance_Ticker") if "YahooFinance_Ticker" in headers else headers.index("Ticker")
        
        tickers = []
        for row in all_data[1:]:
            if len(row) > ticker_idx and row[ticker_idx].strip():
                tickers.append(row[ticker_idx].strip())
        
        if not tickers:
            print("⚠️ 업데이트할 티커가 없습니다")
            return
        
        print(f"🔄 주가 업데이트 중... ({len(tickers)}개 종목)")
        
        # 주가 시트 가져오기 또는 생성
        try:
            price_ws = GSHEET.worksheet("주가")
        except:
            # 시트가 없으면 생성
            price_ws = GSHEET.add_worksheet(title="주가", rows=1000, cols=10)
            price_ws.update("A1", [["Ticker", "현재가", "전일대비", "등락률(%)", "업데이트시간"]])
        
        # 현재 시트 데이터 읽기
        price_data = price_ws.get_all_values()
        price_headers = price_data[0] if price_data else []
        
        # 기존 ticker 행 찾기용 맵
        ticker_row_map = {}
        if len(price_data) > 1:
            ticker_col_idx = price_headers.index("Ticker") if "Ticker" in price_headers else 0
            for idx, row in enumerate(price_data[1:], start=2):
                if len(row) > ticker_col_idx:
                    ticker_row_map[row[ticker_col_idx]] = idx
        
        # 각 ticker의 현재가 조회
        updates = []
        current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        for ticker in tickers:
            try:
                stock = yf.Ticker(ticker)
                info = stock.history(period="2d")
                
                if info.empty or len(info) < 1:
                    continue
                
                current_price = float(info["Close"].iloc[-1])
                prev_close = float(info["Close"].iloc[-2]) if len(info) >= 2 else current_price
                change = current_price - prev_close
                change_pct = (change / prev_close * 100) if prev_close > 0 else 0
                
                row_data = [
                    ticker,
                    round(current_price, 2),
                    round(change, 2),
                    round(change_pct, 2),
                    current_time
                ]
                
                # 기존 행이 있으면 업데이트, 없으면 추가
                if ticker in ticker_row_map:
                    row_num = ticker_row_map[ticker]
                    price_ws.update(f"A{row_num}:E{row_num}", [row_data])
                else:
                    updates.append(row_data)
                
            except Exception as e:
                print(f"⚠️ {ticker} 가격 조회 실패: {e}")
        
        # 새로운 ticker들 일괄 추가
        if updates:
            price_ws.append_rows(updates)
        
        print(f"✅ 주가 업데이트 완료: {len(tickers) - len([t for t in tickers if t not in ticker_row_map])}개 신규, {len(ticker_row_map)}개 갱신")
        
    except Exception as e:
        print(f"⚠️ update_stock_prices 에러: {e}")


def update_exchange_rate():
    """
    USD/KRW 환율을 조회하여 환율 시트에 업데이트
    """
    if not GSHEET:
        print("⚠️ 시트 연결 안 됨")
        return
    
    try:
        print("🔄 환율 업데이트 중...")
        
        # USD/KRW 환율 조회
        try:
            # yfinance로 USD/KRW 조회
            usdkrw = yf.Ticker("KRW=X")
            rate_info = usdkrw.history(period="1d")
            
            if rate_info.empty:
                # 대체: USDKRW.FOREX 또는 고정값
                print("⚠️ yfinance에서 환율 조회 실패, 대체 방법 시도...")
                usdkrw = yf.Ticker("USDKRW=X")
                rate_info = usdkrw.history(period="1d")
            
            if not rate_info.empty:
                exchange_rate = float(rate_info["Close"].iloc[-1])
            else:
                # fallback: 고정값 사용
                exchange_rate = 1450.0
                print("⚠️ 환율 조회 실패, 기본값 사용: 1450")
        except:
            exchange_rate = 1450.0
            print("⚠️ 환율 조회 에러, 기본값 사용: 1450")
        
        # 환율 시트 가져오기 또는 생성
        try:
            fx_ws = GSHEET.worksheet("환율")
        except:
            # 시트가 없으면 생성
            fx_ws = GSHEET.add_worksheet(title="환율", rows=100, cols=5)
            fx_ws.update("A1", [["통화쌍", "환율", "업데이트시간"]])
        
        current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 기존 USD/KRW 행 찾기
        all_data = fx_ws.get_all_values()
        usdkrw_row = None
        for idx, row in enumerate(all_data[1:], start=2):
            if len(row) > 0 and row[0] == "USD/KRW":
                usdkrw_row = idx
                break
        
        row_data = ["USD/KRW", round(exchange_rate, 2), current_time]
        
        if usdkrw_row:
            # 업데이트
            fx_ws.update(f"A{usdkrw_row}:C{usdkrw_row}", [row_data])
        else:
            # 추가
            fx_ws.append_row(row_data)
        
        print(f"✅ 환율 업데이트 완료: USD/KRW = {exchange_rate:.2f}")
        
    except Exception as e:
        print(f"⚠️ update_exchange_rate 에러: {e}")


def update_all():
    """모든 데이터 업데이트"""
    print(f"\n{'='*60}")
    print(f"🕐 {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 데이터 갱신 시작")
    print(f"{'='*60}")
    
    update_stock_prices()
    update_exchange_rate()
    
    print(f"{'='*60}\n")


def main():
    """메인 실행 함수"""
    print("🚀 실시간 데이터 업데이터 시작")
    print("📊 주가와 환율을 1분마다 갱신합니다...")
    
    # 초기화
    initialize_sheet()
    
    if not GSHEET:
        print("❌ 시트 연결 실패. 프로그램을 종료합니다.")
        return
    
    # 즉시 한 번 실행
    update_all()
    
    # 1분마다 실행 스케줄 등록
    schedule.every(1).minutes.do(update_all)
    
    print("✅ 스케줄러 시작됨. Ctrl+C로 종료하세요.\n")
    
    try:
        while True:
            schedule.run_pending()
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\n⏹️  프로그램 종료")


if __name__ == "__main__":
    main()
