# Daily 2.5.17 릴리스 노트

## 적용 범위

이번 릴리스는 iOS IPA 배포를 우선 대상으로 합니다. 사용자의 지시에 따라
GitHub Release에는 iOS IPA 파일만 업로드합니다.

`2.5.16` 태그는 GitHub에 정상 업로드되었지만, 기존 릴리스 워크플로가
Windows 빌드 실패에 묶여 최종 Release 생성 단계가 실행되지 않았습니다.
`2.5.17`은 이 문제를 우회하지 않고 릴리스 경로를 iOS IPA 전용으로 정리한
재시도 릴리스입니다.

macOS, Android, Windows 산출물은 이번 GitHub Release에 포함하지 않습니다.
다만 공유 Flutter 코드와 계정/동기화 정책은 이후 플랫폼 빌드에서 동일하게
검증해야 합니다.

## 변경 사항

- GitHub 이슈 #15, #16 후속 수정 사항을 포함합니다.
- SideStore 등으로 재서명된 IPA에서 Apple 로그인 entitlement가 사라질 수 있는
  경우를 사용자에게 더 명확히 안내합니다.
  - 이 경우 Daily는 Apple 로그인 자체를 억지로 우회하지 않습니다.
  - 사용자는 `Google로 계속`을 사용하거나, TestFlight/App Store 빌드에서
    Apple 로그인을 다시 시도할 수 있습니다.
- Google Drive AppData에서 설정을 복원한 뒤 앱 설정 상태를 즉시 갱신합니다.
  - 다른 기기에서 변경한 분류 색상이 복원되면 설정 화면에도 바로 반영됩니다.
  - 일정 색상은 바뀌었지만 설정의 분류 색상만 오래된 값으로 보이는 문제를
    줄였습니다.
- Windows 빌드 보정도 함께 포함했습니다.
  - Daily는 사용자 표시 버전과 빌드 버전을 모두 `2.5.17`처럼 동일한 점 표기
    버전으로 사용합니다.
  - Windows resource build에서 빈 `FLUTTER_VERSION_BUILD` 값이 발생하면 patch
    번호를 빌드 세그먼트로 사용하도록 보정했습니다.
- GitHub Release 워크플로를 이번 릴리스 목적에 맞게 iOS IPA 전용으로
  단순화했습니다.
  - 기존 전체 플랫폼 릴리스 워크플로는 Windows 빌드 실패 시 iOS IPA도
    업로드되지 않는 구조였습니다.
  - 이번 릴리스에서는 iOS IPA 생성과 GitHub Release 업로드가 Windows 빌드
    상태에 막히지 않습니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- `./tool/flutter.sh build ipa --release --no-pub`
- iOS archive validation:
  - Version Number: `2.5.17`
  - Build Number: `2.5.17`
  - Bundle Identifier: `com.littlebit0.daily`
- GitHub Actions:
  - `Release IPA` workflow completed successfully for tag `v2.5.17`.
  - Release page and uploaded IPA asset were confirmed through the GitHub API.

## 배포 파일

- GitHub Release asset:
  - `daily-ios-2.5.17-unsigned.ipa`
- 로컬 GitHub 업로드용 복사본:
  - `dist/release-2.5.17/daily-ios-2.5.17.ipa`
- 로컬 App Store Connect Transporter 업로드용 복사본:
  - `dist/transporter-upload/Daily-iOS-Transporter-2.5.17.ipa`
- 로컬 실사용 iPhone 설치 확인용 복사본:
  - `dist/device-install/Daily-iOS-Device-2.5.17.ipa`

SHA-256:

- `daily-ios-2.5.17.ipa`:
  `13f9fc31fd20bb368704d0b9065b20fe005bb6c3437e234bfdb606bc980b3416`

## 남은 확인 사항

- `Platform Builds` 워크플로의 Windows debug build는 아직 GitHub Actions에서
  실패합니다. 공개 API와 HTML에서는 상세 로그가 `Process completed with exit
  code 1`까지만 노출되어, 정확한 Windows 실패 원인은 GitHub UI 인증 상태에서
  Actions 로그를 열어 추가 확인이 필요합니다.
- macOS, Android, Windows는 다음 플랫폼 릴리스 전에 iOS와 같은 계정 UX,
  Google Drive AppData 동기화 정책, 로그아웃/회원탈퇴 동작을 다시 검증해야
  합니다.
