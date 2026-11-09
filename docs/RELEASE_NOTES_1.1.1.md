# Daily 1.1.1

Daily 1.1.1은 일정 알림이 실제 기기의 알림센터에서 제대로 뜨도록 고친 버그 수정 릴리스입니다.

## 변경 사항

- macOS 일정 알림을 앱 내부 메시지 대신 macOS Notification Center에 기록하고 표시합니다.
- macOS에서 로컬로 실행하는 앱을 고정된 설치 경로에서 실행합니다. Apple 서명을 쓸 수 있으면 실제 TeamIdentifier가 있는 앱으로 등록합니다.
- macOS 알림을 `UNUserNotificationCenter` 기반 네이티브 채널 하나로 정리했습니다. 이제 legacy 알림 클라이언트와 modern 알림 클라이언트를 함께 쓰지 않습니다.
- 시작 시간이 이미 지난 일정을 저장할 때 알림을 어떻게 처리할지 기준을 정했습니다.
- iOS에서 foreground 알림 delegate를 확실히 등록합니다.
- Android 예약 알림 receiver와 exact alarm 권한 fallback을 보강했습니다.
- 일정 추가·수정 다이얼로그의 검증 메시지를 사용자가 볼 수 있는 위치에 표시합니다. 제목이 비어 있거나 종료 시간이 시작 시간보다 빠른 경우가 여기에 해당합니다.

## 설치 파일

- `daily-macos-1.1.1+2.dmg`: macOS 설치용 DMG입니다.
- `daily-ios-1.1.1+2-unsigned.ipa`: 서명하지 않은 iOS IPA입니다. 실제 iPhone에 설치하려면 Apple Developer 서명을 하거나 연결된 기기를 대상으로 Xcode에서 설치해야 합니다.

## 참고

일반 사용자에게 배포할 수 있는 iPhone용 IPA를 만들려면 Apple Developer Program의 distribution signing과 TestFlight, App Store, Ad Hoc provisioning 중 하나가 필요합니다. 무료 Personal Team 개발 서명은 연결된 개발자 기기에 직접 설치할 때만 쓸 수 있고, 일반 배포용 IPA에는 쓸 수 없습니다.

Apple Personal Team에서는 Time Sensitive Notifications capability를 provisioning할 수 없습니다. 그래서 이번 릴리스는 표준 알림센터 알림으로 배포합니다.
