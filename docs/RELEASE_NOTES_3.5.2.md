# DailyCalendar 3.5.2

## 주요 변경

- 휴대폰·태블릿의 화면 회전 및 창 크기 변경 시 달력 메뉴와 상세 보기 배치를 개선했습니다. 선택 날짜와 보기 상태를 유지합니다.
- 밝은·어두운 테마에서 일정 제목·배경·완료 취소선의 대비를 함께 조정합니다. 저장한 분류 색상은 보존하며 Flutter, Android 위젯, Apple 위젯 및 잠금화면 달력에 반영했습니다.
- Android Google 계정 선택과 Drive 권한 요청을 하나의 작업으로 처리하며, 취소·중복 요청·뒤늦게 도착하는 인증 결과 처리를 개선했습니다.
- iPad 잠금화면 달력 설정과 가로·세로 미리보기를 지원하고, 방향별 화면 잘림과 위젯 공간을 반영했습니다.
- iOS 위치 권한 설명을 지원 언어별로 보완했습니다. 백그라운드 위치 추적 기능을 추가하지 않습니다.

## 업데이트와 배포 파일

3.5.0의 Google Drive AppData v2 및 DB 스키마 8을 유지합니다.

- iOS: `daily-ios-3.5.2-unsigned.ipa` (공개 검증용, 설치하려면 별도 서명 필요)
- macOS: `daily-macos-3.5.2-unsigned.dmg` (공개 검증용, 미공증)
- Android: `daily-android-3.5.2.apk` (버전 코드 352, 기존 배포 서명 유지)
- Windows: `daily-windows-3.5.2-setup.exe`, `daily-windows-3.5.2.zip`
- Linux: `daily-linux-3.5.2-1-amd64.deb`, `daily-linux-3.5.2-1-arm64.deb`

Apple 공개 파일은 Transporter 제출용이 아니며, GitHub 공개는 App Store 승인·출시를 의미하지 않습니다.
Android 3.3.1 이전 서명키와는 호환되지 않으므로 이전 설치본을 삭제하기 전 백업과 복원 가능 여부를 확인하세요.

## 검증 범위

- 공유 Flutter 정적 분석 통과, 전체 자동화 테스트 587개 통과 및 기존 제외 항목 1개.
- 색상 검증은 RGB 각 채널 0,10,…,250,255의 19,683개 조합을 양쪽 테마에서 검사했습니다. 배경·투명도 조합 1,417,176건과 실제 글자 렌더링 39,366건 및 추가 1,440건이 통과했습니다.
- Kotlin·Swift 색상 결과는 공통 Dart 기준 데이터와 일치합니다.
- 실제 계정 로그인, 기기별 알람·위젯, Windows/Linux 데스크톱 실사용은 자동 테스트·빌드 검증과 별개입니다.
- iPad 단축어 실행 및 실제 잠금화면 변경은 사용자 직접 검증 대상으로 남아 있습니다.

[색상 검증 상세](https://github.com/littlebit0/DailyCalendar/blob/v3.5.2/docs/ISSUE_81_COMPLETION_CONTRAST.md)
· [동기화 규칙](https://github.com/littlebit0/DailyCalendar/blob/v3.5.2/docs/SYNC_MERGE_RULES.md)
