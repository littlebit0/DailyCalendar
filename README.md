# DailyCalendar

<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="128" alt="DailyCalendar 앱 아이콘">
</p>

<p align="center">
  일정을 빠르게 기록하고 여러 기기에서 이어서 사용하는 개인 캘린더
</p>

<p align="center">
  <a href="https://github.com/littlebit0/DailyCalendar/releases/latest"><img src="https://img.shields.io/github/v/release/littlebit0/DailyCalendar?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/version-4.0.0-2f6feb" alt="Version 4.0.0">
  <img src="https://img.shields.io/badge/Flutter-iOS%20%7C%20macOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-02569B?logo=flutter" alt="Flutter platforms">
</p>

DailyCalendar는 월간, 주간, 일간 및 연간 보기로 일정을 관리하는 Flutter 기반
크로스 플랫폼 캘린더입니다. 계정 없이 로컬로 사용할 수 있으며, Google 계정을
연결하면 Google Drive AppData를 통해 일정과 설정을 백업하고 동기화할 수
있습니다.

학사정보는 지역 지도와 이름·초성 검색으로 대학을 선택합니다. 지역이 다른 분교는 선택 지역에 맞게 등록합니다. 

학교 시간표 검색은 상명·단국·아주·중앙·이화여자·홍익·인하·부산·세종·서울대학교에서 지원합니다. 학사일정 연동은 [대학 지원 계획](#대학-지원-계획)에 따라 1차 대학부터 다시 지원합니다. 저장한 일정·시간표와 직접 수업 추가는 유지하며, 주·일간 캘린더에는 해당 학기 기간에만 수업을 표시합니다.

[시간표 구조](docs/TIMETABLE.md) · [대학 목록 출처](docs/UNIVERSITY_DIRECTORY_SOURCES.md) · [미완료 대학 및 분류 개선 인계 #92](https://github.com/littlebit0/DailyCalendar/issues/92)

## 4.0.0 주요 변경

- 지역별 대학 선택·교표, 지역에 맞는 분교 자동 선택을 추가했습니다.
- 대학 학사일정을 확대하고 시간표의 교필·교선, 학과와 공식 전공제도 분류를 개선했습니다.
- 기기별 보안 저장소를 사용하는 선택형 LMS 자동 로그인과 퀴즈 완료 상태 처리를 개선했습니다.
- 반복 LMS 조회, 시작 동기화, 완료 취소선과 빠른 보기·시간표·대학 목록 애니메이션을 개선했습니다.

LMS 로그인 정보는 다른 기기로 동기화하지 않으며 일정만 동기화합니다. 학교 정책에 따라 다른 기기의 LMS 세션이 종료될 수 있습니다.

> Drive v2와 DB 스키마 9를 유지합니다. App Store 출시는 GitHub 릴리스와 별개입니다.
> [4.0.0 릴리스 노트](docs/RELEASE_NOTES_4.0.0.md) · [스토어 문구](docs/STORE_TEXT_4.0.0_KO.md)

## 대학 지원 계획

학사일정과 학교 시간표는 대학을 차수로 나누어 다시 지원합니다. 대상은 대학알리미 2026 공시대상 4년제 대학(앱 대학 목록 기준)과 신학대입니다. 학사일정은 기존 연동을 모두 제거했고 1차 대학부터 새로 연결합니다. 학교 시간표 검색은 아래 10개 대학만 유지하고, 나머지 대학의 시간표 원자료는 제거했습니다. 사용자가 이미 저장한 일정·시간표와 직접 추가한 수업은 그대로 유지합니다.

| 차수 | 대학 수 | 범위 |
| --- | ---: | --- |
| 1차 | 72 | 지금 진행하는 지원 대상 |
| 2차 | 60 | 1차 이후 지원 |
| 3차 | 44 | 2차 이후 지원 |
| 4차 | 25 | 신학대 |
| 5차 이후 | 140 | 전문대 계열(전문대학·기능대학·전공대학·사내대학), 나중에 지원 |

현재 학교 시간표 검색 지원(1차 포함): 단국대학교, 부산대학교, 상명대학교, 서울대학교, 세종대학교, 아주대학교, 이화여자대학교, 인하대학교, 중앙대학교, 홍익대학교.

1·2차 조정에는 대학알리미 '우리대학경쟁력'의 학부 전체 재학생 수(2025-04-01 기준, 캠퍼스 합산)를 참고했습니다.

<details>
<summary>1차 지원 대학 (72개)</summary>

가천대학교, 가톨릭대학교, 강원대학교, 건국대학교, 건양대학교, 경기대학교, 경북대학교, 경상국립대학교, 경희대학교, 계명대학교, 고려대학교, 광운대학교, 국립경국대학교, 국립공주대학교, 국립군산대학교, 국립목포대학교, 국립부경대학교, 국립순천대학교, 국립창원대학교, 국립한국교통대학교, 국립한밭대학교, 국민대학교, 남서울대학교, 단국대학교, 대구대학교, 대전대학교, 동국대학교, 동아대학교, 동의대학교, 명지대학교, 배재대학교, 백석대학교, 부산대학교, 상명대학교, 서강대학교, 서경대학교, 서울과학기술대학교, 서울대학교, 서울시립대학교, 서울여자대학교, 선문대학교, 성균관대학교, 성신여자대학교, 세종대학교, 수원대학교, 숙명여자대학교, 순천향대학교, 숭실대학교, 아주대학교, 연세대학교, 영남대학교, 울산대학교, 을지대학교, 이화여자대학교, 인제대학교, 인천대학교, 인하대학교, 전남대학교, 전북대학교, 제주대학교, 조선대학교, 중앙대학교, 충남대학교, 충북대학교, 한국공학대학교, 한국기술교육대학교, 한국외국어대학교, 한국항공대학교, 한성대학교, 한양대학교, 호서대학교, 홍익대학교

</details>

<details>
<summary>2차 지원 대학 (60개)</summary>

가톨릭관동대학교, 가톨릭꽃동네대학교, 강남대학교, 경남대학교, 경인교육대학교, 공주교육대학교, 광주과학기술원, 광주교육대학교, 광주대학교, 광주여자대학교, 국립금오공과대학교, 국립목포해양대학교, 국립한국해양대학교, 극동대학교, 나사렛대학교, 남부대학교, 대구가톨릭대학교, 대구경북과학기술원, 대구교육대학교, 대진대학교, 덕성여자대학교, 동덕여자대학교, 동명대학교, 목포가톨릭대학교, 부산가톨릭대학교, 부산교육대학교, 부산외국어대학교, 삼육대학교, 상지대학교, 서울교육대학교, 서원대학교, 성결대학교, 세명대학교, 안양대학교, 용인대학교, 우석대학교, 우송대학교, 울산과학기술원, 원광대학교, 인천가톨릭대학교, 전주교육대학교, 전주대학교, 진주교육대학교, 차의과학대학교, 청운대학교, 청주교육대학교, 춘천교육대학교, 평택대학교, 포항공과대학교, 한경국립대학교, 한국과학기술원, 한국교원대학교, 한국에너지공과대학교, 한남대학교, 한림대학교, 한서대학교, 한세대학교, 협성대학교, 호남대학교, 호원대학교

</details>

<details>
<summary>3차 지원 대학 (44개)</summary>

가야대학교, 강서대학교, 경동대학교, 경성대학교, 경운대학교, 경일대학교, 경찰대학, 고신대학교, 금강대학교, 김천대학교, 대구예술대학교, 대구한의대학교, 동서대학교, 동신대학교, 동양대학교, 목원대학교, 삼성전자공과대학교, 성공회대학교, 세한대학교, 송원대학교, 신경주대학교, 신라대학교, 신한대학교, 영산대학교, 예수대학교, 예원예술대학교, 위덕대학교, 유원대학교, 정석대학, 제주국제대학교, 중부대학교, 중원대학교, 창신대학교, 청주대학교, 초당대학교, 추계예술대학교, 한국방송통신대학교, 한국예술종합학교, 한국전통문화대학교, 한국체육대학교, 한동대학교, 한라대학교, 한신대학교, 화성의과학대학교

</details>

<details>
<summary>4차 지원 대학 — 신학대 (25개)</summary>

감리교신학대학교, 광신대학교, 광주가톨릭대학교, 대신대학교, 대전가톨릭대학교, 대전신학대학교, 루터대학교, 부산장신대학교, 서울기독대학교, 서울신학대학교, 서울장신대학교, 서울한영대학교, 수원가톨릭대학교, 순복음총회신학교, 아신대학교, 영남신학대학교, 영산선학대학교, 장로회신학대학교, 중앙승가대학교, 총신대학교, 칼빈대학교, 한국성서대학교, 한국침례신학대학교, 한일장신대학교, 호남신학대학교

</details>

## 다운로드

최신 공개 릴리스는 [GitHub Releases](https://github.com/littlebit0/DailyCalendar/releases/latest)에서
확인할 수 있습니다.

| 플랫폼 | 배포 상태 | 파일 |
| --- | --- | --- |
| iPhone / iPad | App Store 무료 배포 중 | App Store의 `DailyCalendar` |
| iOS 테스트 | 4.0.0 공개 검증용 미서명 파일 | [daily-ios-4.0.0-unsigned.ipa](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-ios-4.0.0-unsigned.ipa) |
| macOS 테스트 | 4.0.0 공개 검증용 미서명 파일 | [daily-macos-4.0.0-unsigned.dmg](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-macos-4.0.0-unsigned.dmg) |
| Android | 4.0.0 APK, 기존 3.4.0 배포 서명 유지 | [daily-android-4.0.0.apk](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-android-4.0.0.apk) |
| Windows | 4.0.0 설치 프로그램 및 ZIP | [설치 프로그램](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-windows-4.0.0-setup.exe) · [ZIP](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-windows-4.0.0.zip) |
| Linux AMD64 | 3.6.0 유지, 4.0.0 검사 보류 | [amd64 .deb](https://github.com/littlebit0/DailyCalendar/releases/download/v3.6.0/daily-linux-3.6.0-1-amd64.deb) |
| Linux ARM64 | 4.0.0-1 수동 설치 파일 | [arm64 .deb](https://github.com/littlebit0/DailyCalendar/releases/download/v4.0.0/daily-linux-4.0.0-1-arm64.deb) |

> GitHub의 IPA와 DMG는 App Store 제출 파일이 아닙니다. 미서명 IPA는 별도
> 서명 없이는 iPhone에 직접 설치할 수 없으며, 재서명 과정에서 Sign in with
> Apple 같은 entitlement가 유지되지 않을 수 있습니다. 일반 사용자는 App Store
> 설치본을 권장합니다.

> **Android 3.4.0에서의 서명키 변경:** 이전 키를 사용할 수 없어 새 배포 키를
> 생성했습니다. 기존 3.3.1 APK 위에 덮어쓰기 설치할 수 없습니다. 앱 삭제는
> 로컬 데이터를 지우므로, 삭제 전에 데이터 백업과 복원 가능 여부를 반드시
> 확인하세요. 새 키의 Google OAuth 등록은 2026-09-07 완료했으며, 실제
> 스마트폰 로그인은 검증 대기 중입니다. 설정 반영에 시간이 걸릴 수 있습니다.
> 로컬 모드는 계정 없이 사용할 수 있습니다.
> [서명 및 전환 안내](docs/ANDROID_SIGNING.md)

Windows는 `setup.exe` 설치를 권장합니다. 설치형 Release 앱은 시작할 때 최신
GitHub 릴리스를 확인하며 새 Windows 설치 프로그램이 있으면 자동 업데이트를
진행합니다.

### Linux

4.0.0에서는 ARM64 수동 설치 파일을 제공합니다. AMD64는 보류 원자료 검사로 3.6.0을 유지하며, 자동 APT 채널도 기존 3.6.0을 유지합니다.

Ubuntu/Debian 데스크톱용 `.deb`를 한 번 설치하면 Daily 전용 타이머가 약 6시간마다
서명된 업데이트를 확인합니다. 앱 실행 중이거나 검증에 실패하면 업데이트를
미루며, 일정과 설정은 삭제하지 않습니다. 설치 시 앱을 자동 실행하지 않습니다.

```sh
sudo apt install ./daily-linux-3.6.0-1-amd64.deb
```

Intel/AMD PC는 amd64, ARM64 PC는 arm64 파일을 사용하세요. amd64는 Ubuntu 22.04+,
arm64는 Ubuntu 24.04+를 빌드 기준으로 사용합니다. 두 아키텍처의 Release 빌드와
공개 APT 다운로드·해시 검증이 완료됐으며, amd64에서 설치·자동 업데이트·제거 및
사용자 파일 보존을 검증했습니다. 실제 데스크톱 UI·Google 로그인·알림 전달은
아직 실사용 검증 전입니다. Linux에는 Siri·Apple 위젯·AlarmKit이 제공되지 않습니다.
[설치·업데이트 구조 및 Linux 지원 범위](docs/LINUX_DISTRIBUTION.md)를 확인하세요.

## 주요 기능

### 캘린더와 일정

- 월간, 주간, 일간, 연간 및 빠른 보기
- 주간·일간 시간표형 보기와 종일 일정 표시 제어
- 일정 추가, 수정, 삭제, 검색 및 분류 필터
- 모든 사용자 일정의 Todo 완료 상태와 빠른 보기·위젯 체크
- 반복 일정, 연속 일정, D-day, 음력과 대한민국 공휴일
- 날짜 범위 드래그 입력과 일정 날짜 이동·날짜별 수동 순서
- 외부 캘린더 가져오기
- 선택형 기상청 날씨 예보와 지역 설정
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
- 일정별 증분 동기화, 실제 UTC 변경 시각에 따른 충돌 병합
- 설정별 병합, 삭제된 과거 일정 본문 정리와 재등장 방지
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

위 표는 플랫폼별 기본 기능 지원 범위입니다. 4.0.0의 공유 기능과 동기화 코드는
Windows/Linux 배포 빌드에도 포함합니다. 플랫폼별 실제 로그인·알람·위젯 동작은
빌드 및 자동 테스트와 별도로 확인해야 합니다.

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
- 충돌은 일정별 생성·수정·삭제의 최신 UTC 변경 시각으로 병합
- 분류 이름·색상 등 설정을 항목별로 병합하고 조건부 쓰기로 동시 변경 보호
- 삭제하지 않은 과거 일정은 보존하고, 만료된 삭제 일정만 최소 기록으로 정리
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

릴리스 검증과 지원 범위는 [릴리스 노트](docs/RELEASE_NOTES_4.0.0.md)와
[에이전트 작업 기록](AGENT_MEMORY.md)에 기록합니다. 자동 테스트와 빌드 성공은
실제 사용자 기기의 로그인·알람·위젯 동작 검증과 구분합니다.

## 문서

- [4.0.0 릴리스 노트](docs/RELEASE_NOTES_4.0.0.md)
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
`littlebits12n@gmail.com`으로 받을 수 있습니다.
