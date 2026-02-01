
## 6. 자동화 배포 (Deployment)

`scripts/deploy.sh`를 사용하면 코드 푸시, VM 업데이트, 실행 검증, 재시작이 한 번에 처리됩니다.

### 사용법 (Local)
```bash
./scripts/deploy.sh
```

### 작동 원리
1. **Local**: `git push`로 로컬 변경사항 업로드 (main 브랜치 필수).
2. **VM**:
   - `git pull` & `pip install` (코드/의존성 갱신)
   - `timeout 30s main.py`로 실행 테스트
     - **검증 항목**: Gemini 모델 초기화, 시트 연결 성공 여부
     - **실패 조건**: 404 Model Error, 403 API Key Leaked, 필수 로그 누락 시 **배포 중단**.
   - 테스트 통과 시 `scripts/restart_bot.sh` 실행
3. **Restart**:
   - `tmux` 세션(`stock-bot`)을 강제 종료 후 재생성.
   - 로그는 `bot.log` 및 `tmux` 세션 내에 기록됨.

### 모니터링
배포 후 VM에서 로그를 보려면:
```bash
# 로컬에서 바로 접속하여 로그 보기 (키체인 사용)
ssh -i ~/.ssh/google_compute_engine juhyeon@34.16.2.223 "sudo -u jufamila tmux attach -t stock-bot"
```

### 트러블슈팅
- **배포 실패 (Verification Failed)**: 출력되는 로그 마지막 80줄을 확인하세요.
- **API Key Leaked (403)**: VM에 접속하여 `.env` 파일의 `GEMINI_KEY`를 갱신해야 합니다.
- **Git Conflict**: VM에서 직접 충돌을 해결하거나 `git reset --hard`가 필요할 수 있습니다.
