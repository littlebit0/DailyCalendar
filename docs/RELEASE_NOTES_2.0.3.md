# Daily 2.0.3 릴리스 노트

## 적용 범위

이번 업데이트는 Android와 Windows 빌드에만 적용됩니다. 이번 Windows/Android
작업에서는 macOS와 iOS 아티팩트를 다시 빌드하지 않았습니다.

## 변경 사항

- 음력 표시를 켜면 월간 달력 그리드가 공간을 낭비하던 문제를 고쳤습니다.
  - 양력 날짜와 음력 표시를 같은 고정 헤더 줄에 배치했습니다.
  - 오늘 날짜의 강조 원 때문에 일반 날짜보다 세로 위치가 아래로 밀리던 문제를 고쳤습니다.
  - 일정 막대가 날짜 헤더 바로 아래에서 시작하도록 바꿔 남는 세로 공간을 줄였습니다.
- GitHub 이슈 #2(`v2.0.1`, `v2.0.2`의 iOS/macOS/Windows/Android 공통 UI 비균형 문제)에 맞춰 월간 달력 그리드 코드를 수정했습니다.
- 에이전트가 계속 따르는 작업 규칙 파일 `AGENTS.md`를 저장소 루트에 추가했습니다.
- Windows/Android 공용 Flutter 프로젝트에서 쓰지 않는 Firebase/Auth/Firestore 코드와 의존성을 지웠습니다.
- 이전 Android Firebase 프로젝트 `424765276744`의 오래된 메타데이터를 지웠습니다.
- 쓰지 않는 직접 의존성을 정리하고, 네이티브 SQLite 번들을 명시 의존성으로 바꿨습니다.
- `flutter_secure_storage`를 `10.3.1`로 올렸습니다.
- Android Gradle Plugin을 `8.13.2`로, Kotlin을 `2.3.21`로 올렸습니다.
- Android Kotlin JVM 타깃 설정을 Kotlin `compilerOptions` DSL 방식으로 옮겼습니다.
- Android와 Windows에서 Google 로그인 승인을 기다리는 시간이 맞지 않던 문제를 고쳤습니다.
  - 사용자가 브라우저에서 계정을 고르고 Drive 권한을 승인하는 동안에는 최대 2분까지 기다립니다.
  - 자동 인증, 토큰 교환, 사용자 정보 조회, Drive API 요청, 로그아웃에는 지금처럼 10초 제한을 둡니다.

## 검증

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android debug APK 빌드: `--build-name=2.0.3 --build-number=7`
- Android 설치/업데이트, 실행, 치명 로그 스모크 테스트
- Windows debug 빌드: `--build-name=2.0.3`
- Windows 파일/제품 버전에 `+` 접미사가 없는지 확인
- Windows 재실행 스모크 테스트

## 배포 파일

- `daily-android-2.0.3.apk`
- `daily-windows-2.0.3.zip`
- Android 패키지: `com.littlebit0.dailycalendar`
- Android versionName: `2.0.3`
- Android versionCode: `7`
- Windows product/MSIX 버전: `2.0.3.0`

SHA-256:

- `daily-android-2.0.3.apk`:
  `a9a73c94065658846cb351aa642c6afd7544d01ffba8bb8ff664ac73ba69de63`
- `daily-windows-2.0.3.zip`:
  `e308bc9fb50b33834a2ea7af951bf17aefb179df0cd29330c90143a5b8771a6e`
