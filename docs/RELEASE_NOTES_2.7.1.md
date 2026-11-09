# Daily 2.7.1 릴리스 노트

## 바뀐 점

- 설정에서 기본 일정 알림을 여러 개 고를 수 있습니다.
  - 시작 시, 10분 전, 30분 전, 1시간 전, 1일 전과 직접 입력한 값을 섞어 고를 수 있습니다.
  - 캘린더나 빠른 입력으로 새 일정을 만들면 고른 기본 알림이 모두 붙습니다.
  - 기존 단일 알림 설정과 Google Drive 백업은 따로 손대지 않아도 그대로 쓸 수 있습니다.
- 앱을 다시 실행하거나 업데이트한 뒤에도 Google 계정 연결을 복원합니다.
  - 저장된 세션은 로그인 창을 띄우지 않고 복원합니다.
  - 복원이 잠시 실패하면 다시 시도하고, 그동안에도 로컬 캘린더는 열 수 있습니다.
- macOS Keychain 서명 구성을 고쳐 Google 세션과 앱 잠금 정보가 유지됩니다.
- macOS 주간·일간 보기에서 가로로 스크롤하고, 월간 보기에서 트랙패드로 이동할 수 있습니다.
- 주간·월간·일간 보기의 이전/다음 이동 애니메이션을 하나로 맞췄습니다.
- 모바일 날짜 일정 시트를 위아래로 늘릴 수 있고, 최대 높이까지 늘린 뒤에는 일정 목록을 이어서 스크롤합니다.
- 설정의 앱 정보에 버전과 빌드 번호를 함께 보여 줍니다.

## 동기화와 호환성

- 여러 기본 알림은 Google Drive AppData의 `daily-sync-v2-settings.json`에 저장합니다.
- 기존 `defaultReminderMinutes` 단일 값은 알림 목록의 한 항목으로 자동으로 옮깁니다.
- iOS, macOS, Android, Windows는 같은 설정 형식을 쓰고 일정도 같은 방식으로 만듭니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` (77 tests)
- iPhone 17 시뮬레이터에서 빌드·설치·실행
- macOS 개발 서명으로 빌드·설치·실행
- macOS에서 Google 세션을 끝낸 뒤 자동 복원 확인

## 배포 파일

- `daily-ios-2.7.1-unsigned.ipa`
- `daily-macos-2.7.1-unsigned.dmg`
- `daily-android-2.7.1-debug.apk`
- `daily-windows-2.7.1.zip`

iOS IPA와 macOS DMG는 GitHub 검증용 산출물이며, App Store 제출이나 공증용으로 서명하지 않았습니다.
Android APK는 Play Store 배포 키로 서명하지 않은 디버그 설치본입니다.
