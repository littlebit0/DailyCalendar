# DailyCalendar 감사 인수인계 — 여기서 시작

사용자 요청에 따라 2026-10-13의 감사 기록을 다른 담당자에게 인계한다. **전체 저장소 감사는 미완료이며 이 문서 묶음은 제품 수정 완료 보고가 아니다.**

## 읽는 순서

1. [HANDOFF.md](HANDOFF.md): 오늘 수행한 작업 전체, 정정·보강, 검증 한계, 남은 작업과 재개 절차.
2. [ISSUE_REGISTER.md](ISSUE_REGISTER.md): #93–#170 전체 78개 번호와 수정 진입점. 별도 연계 9건은 구분했다.
3. 전달 ZIP의 `FILE_REVIEW_LEDGER.md`, `RECOVERED_COVERAGE.json`, `checkpoints/`, `evidence/`, `TRANSFER_RECEIPT.json`.

## 게시 중 확인한 다른 담당자의 변경 — 본문과 함께 적용

마지막 감사 기준은 `1f2d8c3a92f4783bfd219ed0c42641451b5c98d8`이다. 인계 문서를 게시하는 동안 다른 담당자의 **`0a7cf88232f4066fbd9ba98b1f141c289ad8f9ac` — Fix legacy database upgrades and recover PIN storage failures**가 `main`에 합쳐졌다. 병합 커밋은 `e20494b830642cdf3ced29b96af11aaf028d95eb`이다.

그 작업은 **#130·#143 구현 및 관련 테스트·문서 변경**을 보고한다. [해당 검증 기록](https://github.com/littlebit0/DailyCalendar/blob/0a7cf88232f4066fbd9ba98b1f141c289ad8f9ac/docs/ISSUES_130_143_VERIFICATION_2026-10-13.md)을 먼저 읽고 실제 현재 코드·이슈 상태·원격 CI를 확인한다. 그 문서는 영향 범위 시험과 Mac 테스트 앱 갱신을 보고하지만, 과거 릴리스 DB 원본·모든 기기 수용·새 전체 CI 성공을 주장하지 않는다. **이 감사 담당자가 그 구현이나 시험을 실행·독립 검증한 것은 아니다.**

따라서 오래된 #130·#143 진단을 그대로 새 결함으로 재등록하거나, 본문의 과거 감사 기준을 현재 코드 전체에 적용하지 않는다. 변경된 파일은 `daily_app.dart`, DB/마이그레이션·설정·지역화 코드, 관련 테스트와 인계 문서다. 이전 기준에서 최종 main까지의 전체 diff에는 다른 담당자의 제품 코드도 포함되므로 이를 이 인계 문서의 변경으로 합산하지 않는다.

이 담당자가 게시한 최초 인계 문서 커밋은 `533fde2751e1d357c4240c724035593e1b2c187c`, 색인 커밋은 `385215b29644af20eb26a893f8c113628ba9d4e1`, 색인의 오탈자 정정은 `0a11361715772ba7d0bc4e84b18f49450a457cbb`다. 해당 작업은 문서만 변경했다. 이 시작 문서의 게시 결과는 최종 전달 영수증에 별도 기록한다.

## 바로 이어갈 감사 위치

`test/features/calendar/calendar_event_drag_layer_test.dart`, `calendar_month_grid_test.dart`, `schedule_timeline_view_test.dart`의 본문과 연결 경로부터 확인한다. 이어 `test/core/lms/lms_credentials_store_test.dart` 및 회수 범위 원장에서 남은 파일을 검토한다. 시작 전에 현재 HEAD와 기준 blob의 차이를 다시 확인한다.

**#87의 철회된 completed 누락 진단을 재사용하지 말 것.** 대학 원자료 수집·지원 확대는 #92에 따라 중단 상태다. 이 인계는 계정 로그인·앱 실행·추가 수집 또는 전체 구현의 별도 승인을 대신하지 않는다.
