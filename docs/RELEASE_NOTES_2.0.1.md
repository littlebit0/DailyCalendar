# Daily 2.0.1 릴리스 노트

## 바뀐 점

- Google Drive 동기화를 실행하는 코드를 플랫폼과 상관없이 공통으로 쓰도록 분리했습니다.
- 일정을 만들거나 고치거나 지우면 바뀐 일정 파일만 Google Drive AppData에 백업합니다. 이때 복원은 하지 않습니다.
- 앱을 시작하거나 다시 열 때, 백그라운드로 보내거나 종료할 때는 Google Drive AppData에서 복원만 합니다.
- 사용자가 전체 동기화를 직접 실행하면 먼저 백업하고, 약 3초 뒤에 복원합니다.
- 설정 화면에서 로컬 백업·복원 섹션을 없애고 Google 계정 동기화만 남겼습니다.
- 릴리스 워크플로를 추가해 GitHub Actions가 Android와 Windows 빌드도 함께 만듭니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub`
- `./tool/flutter.sh build macos --debug --no-pub`
- 지금 Mac에는 Android SDK가 없어서 로컬 Android 빌드는 직접 실행하지 못했습니다.
- macOS 호스트에서는 Windows를 빌드할 수 없어서 로컬 Windows 빌드도 직접 실행하지 못했습니다.
- GitHub Actions 릴리스 워크플로가 Android APK, macOS DMG, iOS unsigned IPA, Windows ZIP을 만듭니다.

## 설치 파일

- `daily-android-2.0.1.apk`: Android에 직접 설치하는 APK입니다.
- `daily-macos-2.0.1.dmg`: macOS에 설치하는 DMG입니다.
- `daily-ios-2.0.1-unsigned.ipa`: 서명하지 않은 iOS 검증용 IPA입니다. 실제 iPhone에 설치하려면 Apple Developer 서명이나 TestFlight 배포가 필요합니다.
- `daily-windows-2.0.1.zip`: Windows 실행 파일과 필요한 DLL을 담은 ZIP입니다.
- `SHA256SUMS.txt`: 업로드한 설치 파일의 SHA-256 체크섬입니다.
