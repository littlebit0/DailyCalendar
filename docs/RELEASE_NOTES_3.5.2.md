# DailyCalendar 3.5.2

## 주요 변경

- 휴대폰과 태블릿에서 화면을 돌리거나 창 크기를 바꿀 때 달력 메뉴와 상세 보기 배치를 고쳤습니다. 선택한 날짜와 보기 상태는 그대로 유지합니다.
- 밝은 테마와 어두운 테마에서 일정 제목, 배경, 완료 취소선의 대비를 함께 조정합니다. 저장한 분류 색상은 바꾸지 않습니다. Flutter, Android 위젯, Apple 위젯, 잠금화면 달력에 같은 기준을 적용했습니다.
- Android에서 Google 계정 선택과 Drive 권한 요청을 한 작업으로 처리합니다. 취소, 중복 요청, 늦게 도착한 인증 결과도 더 정확히 처리합니다.
- iPad에서 잠금화면 달력을 설정하고 가로·세로 미리보기를 볼 수 있습니다. 방향마다 다른 화면 잘림과 위젯 공간을 반영했습니다.
- iOS 위치 권한 설명을 지원 언어마다 보완했습니다. 백그라운드 위치 추적 기능은 추가하지 않았습니다.

## 업데이트와 배포 파일

3.5.0의 Google Drive AppData v2와 DB 스키마 8을 그대로 씁니다.

- iOS: `daily-ios-3.5.2-unsigned.ipa` (공개 검증용, 설치하려면 별도 서명 필요)
- macOS: `daily-macos-3.5.2-unsigned.dmg` (공개 검증용, 미공증)
- Android: `daily-android-3.5.2.apk` (버전 코드 352, 기존 배포 서명 유지)
- Windows: `daily-windows-3.5.2-setup.exe`, `daily-windows-3.5.2.zip`
- Linux: `daily-linux-3.5.2-1-amd64.deb`, `daily-linux-3.5.2-1-arm64.deb`

Apple 공개 파일은 Transporter 제출용이 아닙니다. GitHub에 공개했다고 App Store에서 승인되거나 출시된 것은 아닙니다.
Android 3.3.1 이전 서명키와 호환되지 않습니다. 이전 설치본을 삭제하기 전에 백업하고 복원할 수 있는지 확인하세요.

## 검증 범위

- Linux 서명 APT 채널에 3.5.2-1을 올리고 두 아키텍처의 공개 다운로드를 확인했습니다. [자동 업데이트 채널 검증](https://github.com/littlebit0/DailyCalendar/actions/runs/36107382266)
- 설치 파일 7개의 SHA-256과 내부 버전 검증을 통과했습니다. Android APK가 기존 인증서로 서명된 것도 확인했습니다.
- iOS, macOS, Android, Windows, Linux amd64/arm64 배포 빌드를 모두 통과했습니다. [배포 빌드 결과](https://github.com/littlebit0/DailyCalendar/actions/runs/36106567248)
- Mac 테스트 앱, iPhone·iPad 시뮬레이터, Android 에뮬레이터를 3.5.2로 업데이트하고 기존 데이터가 남아 있는지 확인했습니다.
- 공유 Flutter 정적 분석을 통과했습니다. 전체 자동화 테스트 587개가 통과했고, 기존에 제외한 항목 1개가 있습니다.
- 색상 검증에서는 RGB 각 채널 0,10,…,250,255로 만든 19,683개 조합을 두 테마에서 검사했습니다. 배경·투명도 조합 1,417,176건, 실제 글자 렌더링 39,366건, 추가 검사 1,440건이 통과했습니다.
- Kotlin과 Swift의 색상 결과는 공통 Dart 기준 데이터와 같습니다.
- 실제 계정 로그인, 기기별 알람과 위젯, Windows/Linux 데스크톱 실사용은 자동 테스트와 빌드 검증에 포함되지 않습니다.
- iPad 단축어 실행과 실제 잠금화면 변경은 아직 사용자가 직접 확인해야 합니다.

[색상 검증 상세](https://github.com/littlebit0/DailyCalendar/blob/v3.5.2/docs/ISSUE_81_COMPLETION_CONTRAST.md)
· [동기화 규칙](https://github.com/littlebit0/DailyCalendar/blob/v3.5.2/docs/SYNC_MERGE_RULES.md)
