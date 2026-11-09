# Daily 2.0.1 Release Notes

## 주요 변경

- Google Drive 동기화 실행 방식을 플랫폼 공통으로 분리했습니다.
- 일정 생성, 수정, 삭제 후에는 변경된 일정 파일을 Google Drive AppData에 백업만 합니다.
- 앱 시작, 재개, 백그라운드/종료 진입 시에는 Google Drive AppData에서 복원만 합니다.
- 사용자가 직접 실행하는 전체 동기화는 백업을 먼저 실행한 뒤 약 3초 후 복원을 진행합니다.
- 설정 화면에서 로컬 백업/복원 섹션을 제거하고 Google 계정 동기화만 남겼습니다.
- Android와 Windows 빌드도 GitHub Actions에서 함께 생성하도록 릴리스 워크플로를 추가했습니다.

## 검증

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub`
- `./tool/flutter.sh build macos --debug --no-pub`
- 로컬 Android 빌드는 현재 Mac에 Android SDK가 없어 직접 실행하지 못했습니다.
- 로컬 Windows 빌드는 macOS 호스트 제한으로 직접 실행하지 못했습니다.
- GitHub Actions 릴리스 워크플로에서 Android APK, macOS DMG, iOS unsigned IPA, Windows ZIP을 생성합니다.

## 산출물

- `daily-android-2.0.1.apk`: Android 직접 설치용 APK입니다.
- `daily-macos-2.0.1.dmg`: macOS 설치용 DMG입니다.
- `daily-ios-2.0.1-unsigned.ipa`: 서명되지 않은 iOS 검증용 IPA입니다. 실제 iPhone 설치에는 Apple Developer 서명 또는 TestFlight 배포가 필요합니다.
- `daily-windows-2.0.1.zip`: Windows 실행 파일과 필요한 DLL을 포함한 ZIP입니다.
- `SHA256SUMS.txt`: 업로드된 설치파일의 SHA-256 체크섬입니다.
