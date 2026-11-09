# Daily 2.0.0 릴리스 노트

## 바뀐 점

- Google Drive 동기화를 단일 파일 `daily-sync-v1.json` 방식에서 v2 파일 세트로 바꿨습니다.
- 일정은 일정마다 `daily-sync-v2-event-{eventId}.json` 파일 하나로 저장하고, 설정은 `daily-sync-v2-settings.json`에 따로 저장합니다.
- 일정을 만들거나 고치거나 지우면 바뀐 일정 파일만 업로드합니다.
- 앱을 처음 실행할 때, 로그인한 직후, 앱으로 돌아올 때, 수동 동기화할 때는 v2 일정 파일을 모두 병합해 전체 상태를 맞춥니다.
- Android와 Windows의 Google Drive OAuth/AppData 대상을 iPhone이 쓰는 프로젝트 `234127810480`로 맞췄습니다.
- iPhone에서 만든 하루 종일 일정이 Android와 Windows에서 이틀짜리 일정으로 보이던 날짜 경계 문제를 고쳤습니다.
- 월간 달력을 스와이프하는 도중에 다음 달로 갑자기 넘어가지 않도록 페이지 전환 방식을 고쳤습니다.
- 음력은 양력 날짜 오른쪽에 표시하고, 모든 음력 날짜에 월/일을 함께 표시합니다.
- 주/월/일 전환 버튼과 상단 액션을 더 작게 줄여 달력에 쓰는 공간을 넓혔습니다.

## 확인한 항목

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android debug APK를 빌드해 에뮬레이터에 덮어쓰기 설치
- Windows debug 빌드와 실행
- Android release APK/AAB 빌드
- Windows release 빌드
- Android APK badging: package `com.littlebit0.dailycalendar`, versionName `2.0.0`, versionCode `4`

## 배포 파일

- `daily-android-2.0.0.apk`: Android에 직접 설치하는 APK
- `daily-android-2.0.0.aab`: Google Play Console에 제출하는 App Bundle
- `daily-windows-2.0.0.zip`: Windows에서 권장하는 배포 파일
- `daily-windows-2.0.0.exe`: Windows 실행 파일만 따로 복사한 파일

SHA-256:

- `daily-android-2.0.0.apk`: `5af8f84c9fa8569b7ec9ff0de6bf7417134314f8c744a5dbcba0cf8aebbec37b`
- `daily-android-2.0.0.aab`: `bfef9d5c53a2548ea86d7aa3393ddc3ec1f9644be687bae0aa27bbac78c364ed`
- `daily-windows-2.0.0.zip`: `74de6334baa182344a202aeb5bd24890ec44e44164f6fd6e5d8f8092f8684aef`
- `daily-windows-2.0.0.exe`: `fdec22e38f2e6c95d5da06003b67869eec3fac1c98bcb06e70ed0fb968a8e6ff`

## Mac과 iPhone 인계

macOS와 iOS도 같은 v2 동기화 파일 구조로 바꿔야 합니다. `daily-sync-v1.json`을 쓰는 정상 동기화 경로는 더 이상 쓰지 않습니다. 2.0.0 이후 릴리스에는 Mac/iPhone 산출물만 올리지 말고 Windows/Android 산출물도 함께 올려야 합니다.
