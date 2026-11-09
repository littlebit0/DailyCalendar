# DailyCalendar 3.2.1 릴리스 노트

## 버전 정보

- 앱 표시 버전과 빌드: `3.2.1 (3.2.1)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 비교 기준: `3.2.0`

## 바뀐 점

- Google로 로그인한 사용자는 앱 설정에서 버그 내용을 직접 확인한 뒤
  DailyCalendar GitHub 이슈로 등록할 수 있습니다.
  - 서버가 Google 인증 상태와 이메일 인증 여부를 확인합니다.
  - 공개 이슈에는 제보 내용과 앱 환경만 올리고, Google 이메일은 공개하지
    않습니다.
  - 연락용 이메일은 접근이 제한된 지원 서버에만 보관합니다.
- iPhone과 iPad 설정 화면의 긴 설명이 기기 폭과 글자 크기에 맞춰 단어
  경계에서 줄을 바꿉니다.
- macOS 월간 좌우 보기와 주간·일간 목록/스케줄 보기에서 트랙패드로 좌우
  이동이 되지 않던 회귀를 고쳤습니다.
  - 네이티브 트랙패드 `PointerPanZoom` 페이지 이동을 되살렸습니다.
  - 마우스 휠로 한 단계씩 넘기는 페이지 이동과 스케줄의 세로 시간 이동은
    그대로 둡니다.
- 일정 상세와 macOS 우측 하루 보기의 날짜 헤더에서 공휴일 배경 강조를
  없앴습니다. 이제 일반 날짜와 같은 헤더로 보입니다.
- 개인정보 문서와 서버 운영 문서에 익명 사용성 분석과 인증형 버그 제보의
  수집 범위, 보관 위치, 공개/비공개 경계를 적었습니다.

## 검증한 항목

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 243개
- `python3 -m unittest test/tool/analytics_receiver_test.py` 전체 4개
- macOS 월간·주간·일간 트랙패드 `PointerPanZoom` 회귀 테스트
- macOS Debug 빌드와 테스트 앱 코드 서명 검증
- iOS/macOS 앱과 위젯의 버전과 빌드 `3.2.1 (3.2.1)` 확인

## GitHub 배포 파일

GitHub Actions가 `v3.2.1` 릴리스에서 공개 검증용 파일 두 개를 만듭니다.

- `daily-ios-3.2.1-unsigned.ipa`
- `daily-macos-3.2.1-unsigned.dmg`

GitHub의 unsigned IPA와 DMG는 App Store 제출 파일이 아닙니다. App Store
Transporter에 제출하는 서명 파일은 공개 릴리스에 넣지 않습니다.

## App Store 제출 파일

Transporter 제출용 서명 파일은 로컬 `dist/transporter-upload/3.2.1`에만
만듭니다. Git 저장소와 GitHub Release에는 올리지 않습니다.

## 배포 뒤 확인할 것

- App Store Connect가 iOS 빌드와 macOS 빌드를 각각 올바른 플랫폼으로
  처리하는지 확인합니다.
- 실제 Mac에서 월간 좌우 보기와 주간·일간 목록/스케줄의 트랙패드 이동을
  확인합니다.
- Google로 로그인한 상태에서 버그 제보의 동의와 제출을 확인하고, 공개
  이슈와 비공개 연락처가 나뉘는지 확인합니다.
- App Store Connect 개인정보 응답에 이메일과 고객 지원용 사용자 콘텐츠
  수집 사실을 반영합니다.
