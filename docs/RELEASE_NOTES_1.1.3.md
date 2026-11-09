# Daily 1.1.3 릴리스 노트

## 고친 점

- iPhone Google 로그인에 쓰는 OAuth client를 `com.littlebit0.daily` 전용 iOS client로 바꿨습니다.
- iOS GoogleSignIn 설정에 다른 프로젝트의 server client ID가 섞이지 않도록 `GIDServerClientID`와 `SERVER_CLIENT_ID`를 뺐습니다.
- iOS에서 Google 로그인과 Drive 권한 승인을 기다리는 시간을 사용자가 실제로 조작하는 시간에 맞춰 늘렸습니다.
- iPhone 동기화를 먼저 고친 이유와 아직 남은 전체 플랫폼 OAuth 통합 작업을 `AGENT_MEMORY.md`에 적었습니다.

## 확인한 내용

- `plutil -lint ios/Runner/Info.plist ios/Runner/GoogleService-Info.plist`
- `./tool/flutter.sh analyze`
- `./tool/flutter.sh test`
- iOS simulator debug build
- iOS simulator에서 Google 로그인 계정 선택 화면이 열리는지 확인
- 연결된 iPhone에 development-signed `1.1.3 (3)` 빌드를 설치하고 실행되는지 확인

## 파일

- `daily-ios-1.1.3-signed-development.ipa`: 연결된 개발자 iPhone에 설치하는 development-signed IPA입니다.
- `daily-ios-1.1.3-unsigned.ipa`: 검증용으로 서명하지 않은 IPA입니다.

development-signed IPA는 해당 Apple 개발 팀에 등록된 기기에만 설치할 수 있고, 일반 배포용이 아닙니다. 일반 사용자에게 배포하려면 TestFlight, App Store, Ad Hoc/Enterprise 중 하나의 배포 서명이 필요합니다.

SHA-256:

- `daily-ios-1.1.3-signed-development.ipa`: `c621eb46a4022451382f6916cc5bdb58b55a56c4512966851fbd6a4fb942003b`
- `daily-ios-1.1.3-unsigned.ipa`: `ae90274b1073ba4d6d2eb6e7d4133e2c2e2019e9117c4f7e4a2a1c97c3ec11b4`
