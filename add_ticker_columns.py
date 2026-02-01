#!/usr/bin/env python3
"""
add_ticker_columns.py
Ticker_Info 시트에 매매 파라미터 컬럼 추가:
- Active (매매 활성화 여부)
- 목표비중 (Target Weight)
- 손절기준 (Stop Loss)
- 익절기준 (Take Profit)
"""

import os
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from dotenv import load_dotenv

# .env 로드
load_dotenv()

SERVICE_ACCOUNT_FILE = "service_account.json"
SPREADSHEET_ID = os.getenv("SPREADSHEET_ID", "")


def add_columns():
    """Ticker_Info 시트에 컬럼 추가"""
    try:
        # 구글 시트 연결
        scope = [
            "https://spreadsheets.google.com/feeds",
            "https://www.googleapis.com/auth/drive",
        ]
        creds = ServiceAccountCredentials.from_json_keyfile_name(SERVICE_ACCOUNT_FILE, scope)
        client = gspread.authorize(creds)
        
        if not SPREADSHEET_ID:
            print("❌ SPREADSHEET_ID가 설정되지 않았습니다")
            return False
        
        sheet = client.open_by_key(SPREADSHEET_ID)
        ws = sheet.worksheet("Ticker_Info")
        
        print(f"✅ Ticker_Info 시트 연결 완료")
        
        # 현재 헤더 확인
        headers = ws.row_values(1)
        print(f"📋 현재 헤더 ({len(headers)}개): {headers[:5]}...")
        
        # 추가할 컬럼들
        new_columns = {
            "Active": "TRUE",
            "목표비중": "10%",
            "손절기준": "-15%",
            "익절기준": "30%"
        }
        
        # 이미 존재하는 컬럼 확인
        existing = [col for col in new_columns.keys() if col in headers]
        if existing:
            print(f"⚠️  이미 존재하는 컬럼: {existing}")
            response = input("기존 컬럼을 유지하고 계속하시겠습니까? (y/n): ")
            if response.lower() != 'y':
                print("작업 취소됨")
                return False
        
        # 추가할 컬럼만 필터링
        to_add = {k: v for k, v in new_columns.items() if k not in headers}
        
        if not to_add:
            print("✅ 모든 컬럼이 이미 존재합니다")
            return True
        
        print(f"➕ 추가할 컬럼: {list(to_add.keys())}")
        
        # 시트의 총 행 수 확인
        all_data = ws.get_all_values()
        num_rows = len(all_data)
        
        print(f"📊 현재 데이터: {num_rows}행 (헤더 포함)")
        
        # 새 컬럼을 현재 헤더 끝에 추가
        start_col_idx = len(headers) + 1
        
        for idx, (col_name, default_value) in enumerate(to_add.items()):
            col_idx = start_col_idx + idx
            col_letter = chr(64 + col_idx) if col_idx <= 26 else f"A{chr(64 + col_idx - 26)}"
            
            # 헤더 추가
            ws.update(f"{col_letter}1", [[col_name]])
            print(f"  ✓ {col_letter}1: {col_name}")
            
            # 모든 데이터 행에 기본값 채우기
            if num_rows > 1:
                default_values = [[default_value]] * (num_rows - 1)
                ws.update(f"{col_letter}2:{col_letter}{num_rows}", default_values)
                print(f"    → {col_letter}2:{col_letter}{num_rows}에 기본값 '{default_value}' 설정")
        
        print(f"\n✅ 컬럼 추가 완료!")
        print(f"📝 추가된 컬럼: {list(to_add.keys())}")
        print(f"💡 팁: 각 종목별로 시트에서 직접 값을 수정하세요.")
        
        return True
        
    except Exception as e:
        print(f"❌ 에러 발생: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    print("=" * 60)
    print("Ticker_Info 시트 컬럼 추가 도구")
    print("=" * 60)
    print()
    
    success = add_columns()
    
    print()
    print("=" * 60)
    if success:
        print("✅ 작업 완료")
    else:
        print("❌ 작업 실패")
    print("=" * 60)


if __name__ == "__main__":
    main()
