# Daily 1.1.1

Daily 1.1.1은 알림센터 기반 일정 알림을 실제 사용 환경에서 더 안정적으로 동작하도록 고친 버그 수정 릴리스입니다.

## 변경 사항

- macOS 일정 알림이 앱 내부 메시지가 아니라 macOS Notification Center에 정상 기록되고 표시되도록 수정했습니다.
- macOS 로컬 실행 앱을 안정적인 설치 경로에서 실행하고 Apple 서명이 가능하면 실제 TeamIdentifier가 있는 앱으로 등록하도록 개선했습니다.
- macOS 알림 구현을 최신 `UNUserNotificationCenter` 기반 네이티브 채널로 정리해 legacy/modern 알림 클라이언트 혼용을 제거했습니다.
- 일정 시작 시간이 이미 지난 상태에서 저장한 일정의 알림 처리 기준을 명확히 했습니다.
- iOS foreground 알림 delegate 등록을 보강했습니다.
- Android 예약 알림 receiver와 exact alarm 권한 fallback을 보강했습니다.
- 일정 추가/수정 다이얼로그의 제목 누락, 종료 시간이 시작 시간보다 빠른 경우 등 검증 메시지가 사용자가 볼 수 있는 위치에 표시되도록 개선했습니다.

## 설치 파일

- `daily-macos-1.1.1+2.dmg`: macOS 설치용 DMG입니다.
- `daily-ios-1.1.1+2-unsigned.ipa`: 서명되지 않은 iOS IPA입니다. 실제 iPhone 설치에는 Apple Developer 서명 또는 연결된 기기 대상 Xcode 설치가 필요합니다.

## 참고

실제 iPhone에 일반 배포 가능한 IPA를 제공하려면 Apple Developer Program의 distribution signing과 TestFlight, App Store, 또는 Ad Hoc provisioning이 필요합니다. 무료 Personal Team 개발 서명은 연결된 개발자 기기에 직접 설치하는 용도이며 일반 배포용 IPA로 사용할 수 없습니다.

Time Sensitive Notifications capability는 Apple Personal Team에서 provisioning할 수 없으므로 이번 릴리스는 표준 알림센터 알림으로 배포합니다.
