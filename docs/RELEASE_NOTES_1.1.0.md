# Daily 1.1.0

Daily 1.1.0에서는 일정을 훑어보는 화면과 여러 기기 사이의 이어 쓰기를 손봤습니다.

## 새로 바뀐 점

- 주간, 월간, 일간 보기를 전환할 수 있습니다.
- 앱을 열면 주간 보기가 먼저 나옵니다.
- 월간 달력의 표시 밀도와 배너를 조정해 일정 제목이 잘 보이게 했습니다.
- 일정 검색, 분류 필터, 공휴일 표시 필터, D-day 전용 보기 옵션을 추가했습니다.
- 날짜를 드래그하거나 길게 눌러 여러 날짜를 고른 뒤 일정을 추가할 수 있습니다.
- 반복 일정을 수정하거나 삭제할 때 `이 일정만`, `이후 일정`, `전체 반복 일정` 중에서 범위를 고를 수 있습니다.
- 일정마다 URL, 날씨 메모, 민감 일정 여부를 따로 기록할 수 있습니다.
- 앱 잠금 PIN, 민감 일정 제목 숨김, 민감 일정 알림 숨김 설정을 추가했습니다.
- Google Drive AppData 동기화 상태를 확인하고 필요할 때 바로 다시 동기화할 수 있습니다.
- Android 홈 화면에 월간, 오늘, D-day 위젯 진입점을 추가했습니다.
- Windows에서는 창을 닫아도 앱이 트레이에서 계속 실행되고, 트레이 메뉴에서 미니 캘린더를 열 수 있습니다.
- macOS에서는 마지막 창을 닫아도 앱이 바로 종료되지 않습니다.

## 안정성

- Android에서 Google 로그인 창을 닫거나 응답이 늦어지면 원시 오류 대신 알아보기 쉬운 안내를 보여줍니다.
- 일정 삭제, 반복 일정 편집, 동기화 상태 갱신 흐름을 정리했습니다.
- iOS, iPadOS, macOS, Android, Windows가 같은 Flutter 화면 구조를 쓰도록 UX 흐름을 맞췄습니다.

## 설치 파일

- `daily-android-1.1.0.apk`: Android 기기에 직접 설치하는 파일입니다.
- `daily-android-1.1.0.aab`: Google Play Console에 제출하는 파일입니다.
- `daily-windows-1.1.0.zip`: Windows용 권장 배포 파일입니다.
- `daily-windows-1.1.0.exe`: Windows 실행 파일입니다.

Windows에서는 `daily-windows-1.1.0.zip` 사용을 권장합니다. Windows 앱은 실행 파일과 함께 들어 있는 `data` 폴더와 DLL 파일이 있어야 실행됩니다.

## 참고

- 이번 릴리즈에는 iOS와 macOS 설치 파일이 없습니다. Apple 플랫폼에 배포하려면 macOS, Xcode, Apple Developer 설정이 필요합니다.
- 이번 버전의 Android 위젯은 앱으로 빠르게 들어가는 진입점 역할만 합니다. 위젯 안에 실제 일정 내용을 보여주는 기능은 이후 업데이트에서 개선할 예정입니다.
- Google Drive 동기화는 사용자의 Google Drive AppData 영역에 앱 전용 백업 파일을 저장합니다. 앱 잠금 PIN은 기기 안에만 저장하고 Google Drive로 동기화하지 않습니다.

## SHA-256

- APK: `2D613A066840609832836C205645C9D88E6706DC7C31D9EC42AA5488BD9D73E9`
- AAB: `902C05034389A0F8EEA41F00145A9B69FD619371BE5312F7E27335DCBDAE0143`
- Windows EXE: `47332EA06B42272CDBD3515211B4252F41AA8ADEEE7E2A598D99BA48809352AC`
- Windows ZIP: `247AEC22C6DB458672FC8931626D00EF31AB173261B516B8D896A367B0B2A031`
