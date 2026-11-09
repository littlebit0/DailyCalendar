# Daily 2.6.0 릴리스 노트

## 적용 범위

이번 릴리스는 iOS App Review 재제출에 대응하고 macOS의 Google Drive 연결을
안정화합니다. GitHub Release에는 iOS IPA와 macOS DMG를 함께 올립니다.

## 변경 사항

- Apple 로그인 뒤 Google 로그인 화면이 저절로 열리지 않게 했습니다.
  - Apple로 로그인하면 Google Drive를 연결하지 않아도 로컬 캘린더로 바로
    들어갑니다.
  - 기기에 Google Drive 세션이 남아 있을 때만 조용히 복원합니다.
  - 세션 복원에 실패해도 Apple 로그인은 그대로 끝납니다.
- Apple 계정에 연결한 Google 계정의 이메일과 표시 이름을 로컬 설정에
  저장합니다.
  - 사용자가 직접 Google Drive를 연결하면 Apple 계정과의 연결 관계를
    저장합니다.
  - 계정을 삭제하거나 전체 초기화하면 연결 정보도 함께 지웁니다.
- 설정에서 계정을 지우는 버튼 이름을 `계정 삭제`로 분명하게 바꿨습니다.
  - Apple로만 로그인한 상태에서도 `계정 삭제` 버튼이 보입니다.
  - 삭제를 확인하면 Daily 계정 연결, 로컬 일정과 설정, Google Drive AppData
    백업, Apple과 Google 로그인 정보를 지웁니다.
- 일정에 장소를 입력하면 `지도 바로가기` 버튼이 나타납니다.
  - 버튼 하나에서 카카오맵, 네이버지도, Apple 지도 가운데 하나를 고릅니다.
  - 지도 앱이 없으면 웹 주소나 Apple Maps URL로 엽니다.
- GitHub 이슈 #16 후속 보강:
  - 분류를 추가, 수정, 삭제한 뒤 Google Drive 설정 백업을 한 번 더
    확정합니다. 다른 기기의 설정 화면에 분류 색상이 늦게 반영되던 문제를
    줄였습니다.
- macOS와 Windows 데스크톱의 Google Drive 연결을 안정화했습니다.
  - 브라우저로 전환하는 것을 OAuth 취소로 잘못 판단하던 자동 취소 로직을
    없앴습니다.
  - 인증은 사용자가 완료하거나 `연결 취소`를 직접 누를 때만 끝납니다.
- Android와 Windows의 계정 흐름을 iOS와 macOS 정책에 맞췄습니다.
  - Android는 모바일 인증 중에 `Google 연결 중` 상태를 씁니다.
  - Windows는 macOS처럼 시스템 브라우저로 OAuth를 진행하고, 사용자가 직접
    취소할 때만 멈춥니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- `./tool/flutter.sh build ipa --release --no-pub`
- iOS archive 검증:
  - Version Number: `2.6.0`
  - Build Number: `2.6.0`
  - Bundle Identifier: `com.littlebit0.daily`

## 배포 파일

- GitHub Release IPA:
  - `daily-ios-2.6.0-unsigned.ipa`
- GitHub Release macOS DMG:
  - `daily-macos-2.6.0-unsigned.dmg`
- 로컬 GitHub 업로드용 IPA:
  - `dist/release-2.6.0/daily-ios-2.6.0.ipa`
- 로컬 GitHub 업로드용 macOS DMG:
  - `dist/release-2.6.0/daily-macos-2.6.0.dmg`
- App Store Connect Transporter 업로드용 IPA:
  - `dist/transporter-upload/Daily-iOS-Transporter-2.6.0.ipa`
- 실사용 iPhone 설치 확인용 IPA:
  - `dist/device-install/Daily-iOS-Device-2.6.0.ipa`

SHA-256:

- `daily-ios-2.6.0.ipa`:
  `a748b495d37ff918f5bcd71bcc334a6d4ff12b75b88d139e65645db4a485427c`
- `daily-macos-2.6.0.dmg`:
  `59da7dd629f40b9023cda8b337223e4b394e3b8de36850ef97717d1a2e8346f7`

## App Review 확인 사항

- 새로 설치한 뒤 `Apple로 계속`을 골라도 Google 로그인 화면이 저절로 열리지
  않아야 합니다.
- Google Drive 대화형 로그인은 사용자가 `Google로 계속`이나 설정의 Google
  Drive 연결 버튼을 직접 눌렀을 때만 열립니다.
- Apple로 로그인하면 Google Drive 없이도 앱의 캘린더 기능을 쓸 수 있습니다.
