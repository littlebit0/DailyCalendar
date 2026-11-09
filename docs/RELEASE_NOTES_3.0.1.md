# Daily 3.0.1 릴리스 노트

## 빌드 정보

- 앱 표시 버전과 빌드: `3.0.1 (3.0.1)`
- Apple 앱 번들 ID: `com.littlebit0.daily`
- Apple 위젯 번들 ID: `com.littlebit0.daily.widgets`
- App Store Connect: iOS/macOS 3.0.1 빌드를 업로드했고 처리가 끝났습니다.
- 비교 기준: App Store 공개 버전 `2.7.1`

## 바뀐 점

- 좌우로 월을 넘기는 이동, 위아래로 이어지는 월 스크롤, 12개월 연간 보기를 추가했습니다.
- iOS 홈 화면·잠금 화면 위젯과 macOS 데스크톱·알림 센터 위젯을 추가했습니다.
- iOS에는 AlarmKit 일정 알람을, macOS에는 네이티브 일정 알림을 추가했습니다.
- iOS에서 Apple Calendar와 Google Calendar 일정을 가져올 수 있습니다.
- 가져온 캘린더의 분류 이름, 색상, 반복, 알림 정보를 그대로 보존하고, 같은 일정을 두 번 가져오지 않습니다.
- 분류마다 표시 여부를 정할 수 있고, 드래그나 RGB 값으로 사용자 지정 색상을 고를 수 있습니다.
- 앱 잠금 방식을 PIN 없음, Daily PIN, Apple 시스템 인증 세 가지로 정리했습니다.
- 테마(자동·화이트·다크)와 글자 크기(기본·크게·더 크게) 설정을 추가했습니다.
- Google Drive 백업과 복원을 따로 나눴습니다. 다른 기기의 변경 감지, 충돌 처리,
  제한된 재시도, 분류 색상 동기화도 더 일관되게 동작합니다.
- Apple로 로그인한 뒤 Google 로그인을 강제하지 않습니다. 기존 Google 세션을 조용히
  복원하지 못해도 Apple 모드나 로컬 모드는 그대로 쓸 수 있습니다.
- 제거하기로 한 비공개 일정 기능과 데이터 필드를 앱과 동기화 스키마에서 정리했습니다.
- 검색 전환, 위아래 월 스크롤, 연간 보기 크기 변경, 반복 일정 계산, 위젯 갱신이 빨라졌습니다.
- 월 경계를 넘는 날짜 범위 선택, 빈 날짜 선택, 연간 보기 이동, 잠금 반복 인증,
  Google 세션 복원에서 생기던 오류와 여러 화면 표시 오류를 고쳤습니다.
- 지원하는 iPhone과 Mac 디스플레이에서는 시스템의 동적 고주사율을 사용합니다.

## 검증한 항목

- `./tool/flutter.sh analyze --no-pub`
- `./tool/flutter.sh test --no-pub` 전체 142개
- `./tool/flutter.sh test --no-pub test/widget_test.dart` 48개
- iPhone 17 Simulator debug 빌드와 업데이트 설치
- macOS debug 빌드와 테스트 앱 업데이트 설치
- iOS App Store IPA의 앱/위젯 버전과 빌드 `3.0.1`
- macOS App Store PKG의 앱/위젯 버전과 빌드 `3.0.1`
- iOS/macOS App Store 배포 서명과 번들 ID

## GitHub 배포 파일

- `daily-ios-3.0.1-unsigned.ipa`
- `daily-macos-3.0.1-unsigned.dmg`
- `daily-android-3.0.1-debug.apk`
- `daily-windows-3.0.1.zip`

GitHub에 올린 IPA와 DMG는 App Store 제출용이 아닙니다. App Store에 제출할 서명 파일은
로컬 `dist/transporter-ios-3.0.1`과 `dist/transporter-macos-3.0.1`에 따로
보관합니다.

## 아직 확인할 것

- App Store Connect에서 iOS/macOS 3.0.1 빌드를 선택하고 수출 규정에 응답합니다.
- 두 플랫폼을 심사에 추가한 뒤 최종 제출합니다.
- Android 실제 기기와 Windows 실제 OS에서 공유 설정·동기화 변경 회귀를 검증합니다.
