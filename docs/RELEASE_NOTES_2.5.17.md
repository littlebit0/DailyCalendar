# Daily 2.5.17 릴리스 노트

## 적용 범위

이번 릴리스는 iOS IPA 배포를 우선합니다. 사용자 지시에 따라 GitHub Release에는
iOS IPA 파일만 올립니다.

`2.5.16` 태그는 GitHub에 정상으로 올라갔지만, 기존 릴리스 워크플로가 Windows
빌드 실패에 묶여 최종 Release 생성 단계를 실행하지 못했습니다. `2.5.17`은 이
문제를 우회하지 않고 릴리스 경로를 iOS IPA 전용으로 정리해 다시 낸 릴리스입니다.

이번 GitHub Release에는 macOS, Android, Windows 산출물을 넣지 않습니다. 공유
Flutter 코드와 계정·동기화 정책은 이후 각 플랫폼 빌드에서 똑같이 검증해야
합니다.

## 변경 사항

- GitHub 이슈 #15, #16의 후속 수정을 담았습니다.
- SideStore 등으로 재서명한 IPA에서 Apple 로그인 entitlement가 빠질 수 있는
  경우를 사용자에게 더 분명히 알립니다.
  - 이때 Daily는 Apple 로그인을 억지로 우회하지 않습니다.
  - 사용자는 `Google로 계속`을 쓰거나, TestFlight/App Store 빌드에서 Apple
    로그인을 다시 시도할 수 있습니다.
- Google Drive AppData에서 설정을 복원하면 앱 설정 상태를 바로 갱신합니다.
  - 다른 기기에서 바꾼 분류 색상을 복원하면 설정 화면에도 바로 보입니다.
  - 일정 색상은 바뀌었는데 설정의 분류 색상만 예전 값으로 남아 보이는 문제를
    줄였습니다.
- Windows 빌드 보정도 넣었습니다.
  - Daily는 사용자 표시 버전과 빌드 버전에 `2.5.17`처럼 같은 점 표기 버전을
    씁니다.
  - Windows resource build에서 `FLUTTER_VERSION_BUILD` 값이 비면 patch 번호를
    빌드 세그먼트로 쓰도록 고쳤습니다.
- 이번 릴리스에 맞춰 GitHub Release 워크플로를 iOS IPA 전용으로 단순하게
  바꿨습니다.
  - 기존 전체 플랫폼 릴리스 워크플로에서는 Windows 빌드가 실패하면 iOS IPA도
    올라가지 않았습니다.
  - 이제 iOS IPA 생성과 GitHub Release 업로드는 Windows 빌드 상태와 상관없이
    진행합니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- `./tool/flutter.sh build ipa --release --no-pub`
- iOS archive 검증:
  - Version Number: `2.5.17`
  - Build Number: `2.5.17`
  - Bundle Identifier: `com.littlebit0.daily`
- GitHub Actions:
  - 태그 `v2.5.17`의 `Release IPA` 워크플로가 성공했습니다.
  - GitHub API로 Release 페이지와 업로드한 IPA 자산을 확인했습니다.

## 배포 파일

- GitHub Release 자산:
  - `daily-ios-2.5.17-unsigned.ipa`
- GitHub 업로드용 로컬 복사본:
  - `dist/release-2.5.17/daily-ios-2.5.17.ipa`
- App Store Connect Transporter 업로드용 로컬 복사본:
  - `dist/transporter-upload/Daily-iOS-Transporter-2.5.17.ipa`
- 실사용 iPhone 설치 확인용 로컬 복사본:
  - `dist/device-install/Daily-iOS-Device-2.5.17.ipa`

SHA-256:

- `daily-ios-2.5.17.ipa`:
  `13f9fc31fd20bb368704d0b9065b20fe005bb6c3437e234bfdb606bc980b3416`

## 남은 확인 사항

- `Platform Builds` 워크플로의 Windows debug build는 GitHub Actions에서 아직
  실패합니다. 공개 API와 HTML에는 상세 로그가 `Process completed with exit code 1`
  까지만 나옵니다. 정확한 Windows 실패 원인을 알려면 GitHub UI에 로그인한
  상태에서 Actions 로그를 열어 봐야 합니다.
- 다음 플랫폼 릴리스 전에 macOS, Android, Windows에서 iOS와 같은 계정 UX,
  Google Drive AppData 동기화 정책, 로그아웃·회원탈퇴 동작을 다시 검증해야
  합니다.
