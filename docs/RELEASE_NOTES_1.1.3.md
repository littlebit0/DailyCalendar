# Daily 1.1.3 Release Notes

## 핵심 수정

- iPhone Google 로그인용 OAuth client를 `com.littlebit0.daily` 전용 iOS client로 교체했습니다.
- iOS GoogleSignIn 설정에서 다른 프로젝트의 server client ID가 섞이지 않도록 `GIDServerClientID`와 `SERVER_CLIENT_ID`를 제거했습니다.
- iOS Google 로그인과 Drive 권한 승인 대기 시간을 실제 사용자 조작에 맞게 늘렸습니다.
- iPhone 우선 동기화 원인과 남은 전체 플랫폼 OAuth 통합 작업을 `AGENT_MEMORY.md`에 기록했습니다.

## 검증

- `plutil -lint ios/Runner/Info.plist ios/Runner/GoogleService-Info.plist`
- `./tool/flutter.sh analyze`
- `./tool/flutter.sh test`
- iOS simulator debug build
- iOS simulator Google 로그인 계정 선택 화면 진입 확인
- 연결된 iPhone에 development-signed `1.1.3 (3)` 빌드 설치 및 실행 확인

## 산출물

- `daily-ios-1.1.3-signed-development.ipa`: 연결된 개발자 iPhone 설치용 development-signed IPA입니다.
- `daily-ios-1.1.3-unsigned.ipa`: 서명되지 않은 검증용 IPA입니다.

development-signed IPA는 해당 Apple 개발 팀에 등록된 기기 설치용이며 일반 배포용 IPA가 아닙니다. 일반 사용자 배포에는 TestFlight, App Store, 또는 Ad Hoc/Enterprise 배포 서명이 필요합니다.

SHA-256:

- `daily-ios-1.1.3-signed-development.ipa`: `c621eb46a4022451382f6916cc5bdb58b55a56c4512966851fbd6a4fb942003b`
- `daily-ios-1.1.3-unsigned.ipa`: `ae90274b1073ba4d6d2eb6e7d4133e2c2e2019e9117c4f7e4a2a1c97c3ec11b4`
