# Daily 3.1.0 릴리스 노트

## 버전 정보

- 앱 표시 버전과 빌드: `3.1.0 (3.1.0)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준 버전: `3.0.1`

## 바뀐 점

- iOS와 macOS에서 Siri와 App Intents로 일정을 조회, 검색, 추가, 수정, 삭제할
  수 있습니다.
- Siri는 일정을 바꾸기 전에 필요한 제목, 날짜, 시간, 종일 여부, 분류를 확인하고
  사용자에게 확인을 받습니다.
- Siri로 바꾼 일정은 앱의 알림, 알람, 위젯, Google Drive 동기화에 바로
  반영됩니다. 로컬 작업이 실패하면 다시 시도합니다.
- 설정에서 Siri 실행 기록과 상세 결과를 날짜별로 볼 수 있습니다.
- 한국어, 영어, 일본어, 중국어 번체를 지원합니다. 시스템 언어를 자동으로 따르고,
  앱 안에서 언어를 직접 고를 수도 있습니다.
- 주간·일간 캘린더에 시간대별로 스크롤하는 시간표형 보기를 추가했습니다. 종일
  일정을 어떻게 표시할지도 조절할 수 있습니다.
- 캘린더 보기 전환, 빠른 보기, 일정 편집, 설정, 가져오기 화면의 다국어 표시와
  반응형 레이아웃을 손봤습니다.
- Google Drive 동기화 뒤 설정, 알림, 알람, 위젯 상태가 어긋나지 않고 함께
  갱신되도록 고쳤습니다.
- iOS, macOS, Windows 앱 아이콘을 새 DailyCalendar 디자인으로 바꿨습니다.
- Windows 설치 프로그램을 추가하고, GitHub 릴리스에서 자동으로 업데이트하는
  경로를 만들었습니다.

## 검증한 항목

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 165개
- iOS App Store IPA 아카이브와 배포 서명 검증
- macOS App Store PKG 아카이브, 앱 배포 서명, 설치 프로그램 서명 검증
- iOS/macOS 앱과 위젯의 버전과 빌드가 `3.1.0 (3.1.0)`인지 확인

## GitHub 배포 파일

GitHub Actions가 `v3.1.0` Apple 릴리스에서 다음 공개 배포 파일을 만듭니다.

- `daily-ios-3.1.0-unsigned.ipa`
- `daily-macos-3.1.0-unsigned.dmg`

GitHub에 올라가는 unsigned IPA와 DMG는 App Store에 제출하는 파일이 아닙니다.
App Store Transporter로 제출하는 서명 파일은 공개 릴리스에 넣지 않습니다.

## 아직 확인할 것

- App Store Connect에서 iOS/macOS 3.1.0 빌드 처리 확인과 심사 제출
- 실제 iPhone과 Mac에서 Siri 문장 인식과 권한 흐름 최종 확인
- 실제 Android 기기와 Windows에서 3.1.0 회귀 검증
