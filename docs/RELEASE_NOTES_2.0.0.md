# Daily 2.0.0 Release Notes

## 주요 변경

- Google Drive 동기화를 기존 단일 `daily-sync-v1.json` 방식에서 v2 파일 세트로 전환했습니다.
- 일정은 `daily-sync-v2-event-{eventId}.json`으로 일정별 저장하며, 설정은 `daily-sync-v2-settings.json`으로 분리합니다.
- 일정 생성, 수정, 삭제 후 동기화는 변경된 일정 파일만 업로드합니다.
- 앱 첫 실행, 로그인 직후, 포그라운드 복귀, 수동 동기화에서는 v2 일정 파일을 병합해 전체 상태를 맞춥니다.
- Android/Windows의 Google Drive OAuth/AppData 대상은 iPhone 기준 프로젝트 `234127810480`에 맞췄습니다.
- iPhone에서 만든 하루 종일 일정이 Android/Windows에서 이틀 일정처럼 보이던 날짜 경계 문제를 수정했습니다.
- 월간 달력 스와이프가 중간에 갑자기 다음 달로 바뀌지 않도록 페이지 전환 방식을 개선했습니다.
- 음력 표시는 양력 일자 오른쪽에 표시하고, 모든 음력 날짜에 월/일을 함께 표시합니다.
- 주/월/일 전환과 상단 액션을 더 압축해 달력 공간 활용을 개선했습니다.

## 검증

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android debug APK 빌드 및 에뮬레이터 덮어쓰기 설치
- Windows debug 빌드 및 실행
- Android release APK/AAB 빌드
- Windows release 빌드
- Android APK badging 확인: package `com.littlebit0.dailycalendar`, versionName `2.0.0`, versionCode `4`

## 산출물

- `daily-android-2.0.0.apk`: Android 직접 설치용 APK
- `daily-android-2.0.0.aab`: Google Play Console 제출용 App Bundle
- `daily-windows-2.0.0.zip`: Windows 권장 배포 파일
- `daily-windows-2.0.0.exe`: Windows 실행 파일 단독 복사본

SHA-256:

- `daily-android-2.0.0.apk`: `5af8f84c9fa8569b7ec9ff0de6bf7417134314f8c744a5dbcba0cf8aebbec37b`
- `daily-android-2.0.0.aab`: `bfef9d5c53a2548ea86d7aa3393ddc3ec1f9644be687bae0aa27bbac78c364ed`
- `daily-windows-2.0.0.zip`: `74de6334baa182344a202aeb5bd24890ec44e44164f6fd6e5d8f8092f8684aef`
- `daily-windows-2.0.0.exe`: `fdec22e38f2e6c95d5da06003b67869eec3fac1c98bcb06e70ed0fb968a8e6ff`

## 플랫폼 인수인계

macOS/iOS도 같은 v2 동기화 파일 레이아웃으로 갈아엎어야 합니다. `daily-sync-v1.json` 정상 동기화 경로는 폐기하며, 2.0.0 이후 릴리스는 Mac/iPhone 산출물만 업로드하지 말고 Windows/Android 산출물도 함께 업로드해야 합니다.
