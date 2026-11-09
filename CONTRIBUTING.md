# DailyCalendar 개발 안내

DailyCalendar를 직접 빌드하거나 고치려는 분을 위한 문서입니다. 앱 사용 안내는 [README](README.md)에 있습니다.

## 요구 사항

- Flutter SDK
- Dart SDK `^3.11.5`
- Apple 빌드: Xcode 및 Apple Developer 서명 환경
- Android 빌드: Android Studio 또는 Android SDK
- Windows 빌드: Visual Studio의 Desktop development with C++ 워크로드

## 설치와 실행

```bash
git clone https://github.com/littlebit0/DailyCalendar.git
cd DailyCalendar
./tool/flutter.sh pub get
./tool/flutter.sh run -d macos
```

iOS Simulator에서 실행할 때는 기기 ID를 먼저 확인합니다.

```bash
./tool/flutter.sh devices
./tool/flutter.sh run -d <simulator-device-id>
```

Windows에서는 `tool/flutter.ps1`을 사용합니다.

```powershell
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 run -d windows
```

Google OAuth 및 Apple 서명 값은 저장소에 포함하지 않습니다. 로컬 설정 방법은
[Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)과
[Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)을 확인하세요.

## 품질 확인

```bash
./tool/flutter.sh analyze --no-pub
./tool/flutter.sh test --no-pub
```

릴리스 검증과 지원 범위는 [릴리스 노트](docs/RELEASE_NOTES_4.1.1.md)와
[에이전트 작업 기록](AGENT_MEMORY.md)에 기록합니다. 자동 테스트와 빌드 성공은
실제 사용자 기기의 로그인·알람·위젯 동작 검증과 구분합니다.

## 동기화 파일 형식

Google Drive AppData에는 일정별 파일과 설정 파일을 따로 저장합니다.

```text
daily-sync-v2-event-{eventId}.json
daily-sync-v2-settings.json
```

구성 방법과 데이터 형식은 [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)을 참고하세요.

## 문서

- [4.1.1 릴리스 노트](docs/RELEASE_NOTES_4.1.1.md)
- [4.1.0 릴리스 노트](docs/RELEASE_NOTES_4.1.0.md)
- [기능 로드맵](docs/FEATURE_ROADMAP.md)
- [프로젝트 분석](PROJECT_ANALYSIS.md)
- [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)
- [Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)
- [개인정보 처리방침](docs/PRIVACY_POLICY.md)
- [릴리스 체크리스트](docs/RELEASE_CHECKLIST.md)
- [시간표 구조](docs/TIMETABLE.md)
- [대학 목록 출처](docs/UNIVERSITY_DIRECTORY_SOURCES.md)
- [미완료 대학 및 분류 개선 인계 #92](https://github.com/littlebit0/DailyCalendar/issues/92)
