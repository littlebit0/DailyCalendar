# DailyCalendar

<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="128" alt="DailyCalendar 앱 아이콘">
</p>

<p align="center">
  일정을 빠르게 기록하고 여러 기기에서 이어서 사용하는 개인 캘린더
</p>

<p align="center">
  <a href="https://github.com/littlebit0/DailyCalendar/releases/latest"><img src="https://img.shields.io/github/v/release/littlebit0/DailyCalendar?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/version-3.4.0-2f6feb" alt="Version 3.4.0">
  <img src="https://img.shields.io/badge/Flutter-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows-02569B?logo=flutter" alt="Flutter platforms">
</p>

DailyCalendar는 월간, 주간, 일간 및 연간 보기로 일정을 관리하는 Flutter 기반
크로스 플랫폼 캘린더입니다. 계정 없이 로컬로 사용할 수 있으며, Google 계정을
연결하면 Google Drive AppData를 통해 일정과 설정을 백업하고 동기화할 수
있습니다.

## 3.4.0 주요 변경

- 일정 드래그로 날짜·순서를 변경하고, 주·일간 스케줄에서는 30분 단위로 시간을 이동합니다.
- 드래그 중 원래 자리 비우기, 대상 화면에 맞는 일정 크기 전환과 저장 시 깜빡임을 개선했습니다.
- 모바일 하루보기 팝업 밖으로 일정을 옮기면 월간 달력 전체를 확인할 수 있습니다.
- 일정 더블클릭·더블탭으로 완료/미완료를 전환하며, 완료 후에도 분류 색상을 유지합니다.
- 첫 화면을 빠른 보기/주/월/일 중 선택하고, 빠른 보기는 항상 좌우로 월을 이동합니다.
- 날짜·요일·공휴일 표시, macOS 휠 이동, 좁은 화면의 설정 문구와 Android 로그인·알람·위젯을 개선했습니다.

> **Windows에는 이번 최신 변경사항이 미적용 상태입니다.** Windows 전용 반영과
> 실제 OS 검증·업데이트는 후속 작업이며, 공유 코드나 버전 번호 변경만으로
> 적용 완료를 의미하지 않습니다. 변경 내용은 [3.4.0 릴리스 노트](docs/RELEASE_NOTES_3.4.0.md)를 확인하세요.

## 다운로드

최신 공개 릴리스는 [GitHub Releases](https://github.com/littlebit0/DailyCalendar/releases/latest)에서
확인할 수 있습니다.

| 플랫폼 | 배포 상태 | 파일 |
| --- | --- | --- |
| iPhone / iPad | App Store 무료 배포 중 | App Store의 `DailyCalendar` |
| iOS 테스트 | 3.4.0 공개 검증용 미서명 파일 | [daily-ios-3.4.0-unsigned.ipa](https://github.com/littlebit0/DailyCalendar/releases/download/v3.4.0/daily-ios-3.4.0-unsigned.ipa) |
| macOS 테스트 | 3.4.0 공개 검증용 미서명 파일 | [daily-macos-3.4.0-unsigned.dmg](https://github.com/littlebit0/DailyCalendar/releases/download/v3.4.0/daily-macos-3.4.0-unsigned.dmg) |
| Android | 3.4.0 새 서명 APK 빌드 완료, Google OAuth 등록 확인 후 게시 예정 | [이전 공개 APK 3.3.1](https://github.com/littlebit0/DailyCalendar/releases/download/v3.3.1/daily-android-3.3.1.apk) |
| Windows | 최신 변경 미적용, 기존 공개 버전 3.3.1 | [설치 프로그램](https://github.com/littlebit0/DailyCalendar/releases/download/v3.3.1/daily-windows-3.3.1-setup.exe) · [ZIP](https://github.com/littlebit0/DailyCalendar/releases/download/v3.3.1/daily-windows-3.3.1.zip) |

> GitHub의 IPA와 DMG는 App Store 제출 파일이 아닙니다. 미서명 IPA는 별도
> 서명 없이는 iPhone에 직접 설치할 수 없으며, 재서명 과정에서 Sign in with
> Apple 같은 entitlement가 유지되지 않을 수 있습니다. 일반 사용자는 App Store
> 설치본을 권장합니다.

> **Android 3.4.0 서명키 변경:** 이전 키를 사용할 수 없어 새 배포 키를
> 생성했습니다. 기존 3.3.1 APK 위에 덮어쓰기 설치할 수 없습니다. 앱 삭제는
> 로컬 데이터를 지우므로, 삭제 전에 데이터 백업과 복원 가능 여부를 반드시
> 확인하세요. 새 키의 Google 로그인 등록은 확인 대기 중입니다.
> [서명 및 전환 안내](docs/ANDROID_SIGNING.md)

Windows는 `setup.exe` 설치를 권장합니다. 설치형 Release 앱은 시작할 때 최신
GitHub 릴리스를 확인하며 새 Windows 설치 프로그램이 있으면 자동 업데이트를
진행합니다.

## 주요 기능

### 캘린더와 일정

- 월간, 주간, 일간, 연간 및 빠른 보기
- 주간·일간 시간표형 보기와 종일 일정 표시 제어
- 일정 추가, 수정, 삭제, 검색 및 분류 필터
- 모든 사용자 일정의 Todo 완료 상태와 빠른 보기·위젯 체크
- 반복 일정, 연속 일정, D-day, 음력과 대한민국 공휴일
- 날짜 범위 드래그 입력과 일정 날짜 이동·날짜별 수동 순서
- 외부 캘린더 가져오기
- 위치, 지도 바로가기, 링크, 메모와 날씨 정보

### 알림과 위젯

- 일정별 복수 알림과 아침 브리핑
- iOS 26 이상 일정별 시스템 알람
- iPhone, iPad 및 macOS의 오늘 일정·주간·월간·D-day 위젯
- Android 월간·오늘 일정·D-day 홈 화면 위젯과 위젯 Todo 체크
- Windows 트레이 미니 캘린더와 일정 Todo 체크
- 위젯 Todo 체크와 앱 테마에 따른 자동·화이트·다크 표시
- iPhone 및 iPad 잠금화면 위젯
- 일정 변경 시 알림, 알람과 위젯 즉시 갱신

### Siri와 자동화

- iOS 및 macOS Siri/App Intents 일정 조회, 검색, 추가, 수정과 삭제
- 일정 변경 전 필수 정보 확인과 사용자 승인
- 설정에서 날짜별 Siri 실행 기록 및 상세 결과 확인
- Siri 작업 결과를 캘린더, 위젯, 알림과 동기화 상태에 즉시 반영

### 계정과 동기화

- 계정 없는 로컬 모드
- iOS 및 macOS Sign in with Apple
- 선택형 Google 계정 연결
- Google Drive AppData 기반 일정·설정 백업 및 동기화
- 일정별 증분 동기화, 삭제 tombstone과 충돌 병합
- 통합 로그아웃 및 로컬·클라우드 데이터 삭제 흐름

### 개인 설정

- 한국어, 영어, 일본어, 중국어 번체
- 시스템 언어 자동 적용 및 앱별 언어 선택
- 라이트·다크 테마와 반응형 글자 크기
- Apple 플랫폼과 통일된 단계형 온보딩, 빠른 보기와 그룹형 설정 화면
- 사용자 분류, 직접 선택 색상, 분류 순서와 일정 정렬 우선순위
- 공휴일 분류 색상과 선택형 공휴일 날짜 배경
- PIN 없음 보호, Daily PIN 및 Apple 시스템 인증 앱 잠금

## 플랫폼

| 기능 | iOS / iPadOS | macOS | Android | Windows |
| --- | :---: | :---: | :---: | :---: |
| 캘린더와 로컬 저장 | O | O | O | O |
| Google Drive AppData 동기화 | O | O | O | O |
| Sign in with Apple | O | O | - | - |
| Siri / App Intents | O | O | - | - |
| 홈 화면 위젯·미니 캘린더 | O | O | O | O |
| 앱 잠금 | O | O | O | O |

위 표는 기존 기본 기능 지원 범위입니다. 3.4.0의 최신 변경사항은 iOS/macOS/Android
기준이며 Windows에는 미적용 상태입니다. Windows 3.3.1의 기존 트레이 미니
캘린더와 자동 업데이트 기능은 유지되지만, 이번 변경의 적용 완료로 해석하지 않습니다.

## 데이터와 개인정보 보호

- 일정과 설정은 기본적으로 기기의 로컬 SQLite 데이터베이스에 저장됩니다.
- Google 연결은 선택 사항이며 앱 전용 `appDataFolder`만 사용합니다.
- 일반 Google Drive 파일은 읽거나 수정하지 않습니다.
- 별도 일정 백엔드 서버를 운영하지 않습니다.
- 광고, IDFA, 광고 측정, 데이터 브로커 공유 및 앱 간 사용자 추적을 사용하지
  않습니다.

자세한 내용은 [개인정보 처리방침](docs/PRIVACY_POLICY.md)과
[개인정보 및 보안 설계](docs/PRIVACY_AND_SECURITY.md)를 확인하세요.

익명 사용성 분석은 기본적으로 꺼져 있으며 사용자가 설정에서 명시적으로
허용한 경우에만 작동합니다. 일정 내용, 검색어, 계정 정보, 광고 식별자 및
지속적인 기기 식별자는 분석 데이터에 포함하지 않습니다.

Google 로그인 사용자는 설정의 버그 제보에서 내용을 확인한 뒤 DailyCalendar
GitHub 이슈를 자동 등록할 수 있습니다. 연락용 Google 이메일은 공개 이슈에
포함하지 않고, 지원 대응을 위한 비공개 서버 정보로만 제한 보관합니다.

## 동기화 방식

DailyCalendar는 Google Drive AppData에 일정별 파일과 설정 파일을 분리해
저장합니다.

```text
daily-sync-v2-event-{eventId}.json
daily-sync-v2-settings.json
```

- 일정 생성·수정·삭제 시 변경된 일정만 업로드
- 삭제 상태는 tombstone으로 다른 기기에 전파
- 충돌은 일정별 `updatedAt` 또는 `deletedAt` 기준으로 병합
- 종일 일정은 날짜 전용 필드로 보존해 시간대에 따른 날짜 밀림 방지
- 앱 시작, 로그인, 포그라운드 복귀와 수동 요청 시 필요한 동기화 수행

구성 방법과 데이터 형식은
[Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)을 참고하세요.

## 개발 시작

### 요구 사항

- Flutter SDK
- Dart SDK `^3.11.5`
- Apple 빌드: Xcode 및 Apple Developer 서명 환경
- Android 빌드: Android Studio 또는 Android SDK
- Windows 빌드: Visual Studio의 Desktop development with C++ 워크로드

### 설치와 실행

```bash
git clone https://github.com/littlebit0/DailyCalendar.git
cd DailyCalendar
./tool/flutter.sh pub get
./tool/flutter.sh run -d macos
```

iOS Simulator 실행 예시:

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

3.4.0 소스 기준 검증 결과:

- Flutter 정적 분석 통과
- 전체 Flutter 자동화 테스트 368개 통과, 기존 건너뜀 1개
- 플랫폼 구성 테스트 12개 및 앱·위젯 버전 `3.4.0 (3.4.0)` 설정 검사 통과
- 직전 테스트 빌드의 macOS/iOS/Android 업데이트 시 일정·설정 데이터 보존 확인
- Windows 최신 변경 미적용: Windows 빌드·실사용 검증·업데이트는 별도 진행 필요
- 자동 테스트와 빌드 검증은 실제 사용자 기기의 로그인·알람·위젯 동작 보장을 의미하지 않습니다.

## 문서

- [3.4.0 릴리스 노트](docs/RELEASE_NOTES_3.4.0.md)
- [기능 로드맵](docs/FEATURE_ROADMAP.md)
- [프로젝트 분석](PROJECT_ANALYSIS.md)
- [Google Drive 동기화 설정](docs/GOOGLE_DRIVE_SYNC_SETUP.md)
- [Apple 빌드 설정](docs/APPLE_BUILD_SETUP.md)
- [개인정보 처리방침](docs/PRIVACY_POLICY.md)
- [릴리스 체크리스트](docs/RELEASE_CHECKLIST.md)

## 문의와 이슈

Google 로그인 사용자는 앱 설정의 `버그 제보`를 이용할 수 있으며, 직접 확인한
내용만 [GitHub Issues](https://github.com/littlebit0/DailyCalendar/issues)에 공개
등록됩니다. 기능 제안은 GitHub Issues를 이용해 주세요. 개인정보 및 지원 문의는
`kimhee8953@naver.com`으로 받을 수 있습니다.
