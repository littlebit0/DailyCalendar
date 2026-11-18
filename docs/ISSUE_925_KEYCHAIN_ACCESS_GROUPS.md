# 이슈 #925 기록: iOS `keychain-access-groups` 빈 배열

기준: `main` `bd0f3bc41` (2026-11-19). 코드·entitlements 변경 없음.

## 결론

- 서명된 4.2.0 App Store용 ipa에서 `Runner.app`의 `keychain-access-groups`는 빈 배열이고, `application-identifier`(팀 접두어 + `com.littlebit0.daily`)가 함께 들어 있습니다. 위젯 확장(`DailyWidgets.appex`)에는 이 키가 없습니다.
- Apple 문서상 접근 그룹 목록은 `keychain-access-groups` 항목, 앱 ID, 앱 그룹 순서입니다. 첫 항목이 없으므로 기본 그룹은 앱 ID입니다. 앱은 보안 저장 플러그인에 `groupId`를 넘기지 않으므로 모든 항목이 앱 ID 그룹에 저장됩니다.
- 업데이트 설치 뒤 기존 보안 저장값이 남는지는 **실기기에서 아직 확인하지 못했습니다.** 아래 검증 앱은 기기에 설치까지 했고, 기기가 잠겨 있어 실행하지 못했습니다.

## entitlements 이력

| 범위 | `Runner.entitlements`의 `keychain-access-groups` |
| --- | --- |
| 2.7.1 이전 | 키 없음 |
| 2.7.1(`c48350c1c`, 2026-07-21)부터 현재까지 | 빈 배열 |

두 경우 모두 기본 그룹은 앱 ID입니다. 그래서 확인할 업데이트 경로는 "키 없음 → 빈 배열"과 "빈 배열 → 빈 배열" 두 가지입니다.

## 앱의 보안 저장 사용 방식

- 기본 옵션 `const FlutterSecureStorage()`: 설정(`lib/core/settings/settings_repository.dart`), Google 인증(`lib/core/sync/google_drive_auth_service.dart`), LMS 웹 세션, 분석 설정.
- LMS 계정: `IOSOptions(synchronizable: false, accessibility: KeychainAccessibility.unlocked_this_device)` (`lib/core/lms/lms_credentials_store.dart`).
- 플러그인은 `third_party/flutter_secure_storage_darwin`이며 `groupId`가 있을 때만 `kSecAttrAccessGroup`을 지정합니다.

## 실기기 검증 방법

App Store 앱(`com.littlebit0.daily`)을 덮어쓰지 않도록 별도 번들 ID로 검증합니다.

- 검증 앱: 번들 ID `com.littlebit0.keychaincheck`, 저장소의 `third_party/flutter_secure_storage`와 `flutter_secure_storage_darwin`을 그대로 씁니다. 위의 두 옵션(기본, LMS)으로 값을 쓰고 `readAll`로 읽어 콘솔에 출력합니다. 값은 테스트용 문자열(`test-<옵션>-<단계>`)만 씁니다.
- 서명: 같은 팀의 Xcode 관리 와일드카드 개발 프로필(`iOS Team Provisioning Profile: *`)입니다. 개발자 포털 변경은 없습니다.
- 단계: 같은 번들 ID로 a → b → c 순서로 업데이트 설치하고 매번 실행합니다.

| 단계 | 버전 | `keychain-access-groups` | 하는 일 |
| --- | --- | --- | --- |
| a | 1.0.0 (1) | 키 없음 | a 값 쓰기 |
| b | 1.0.1 (2) | 빈 배열 | a 값이 남았는지 읽기, b 값 쓰기 |
| c | 1.0.2 (3) | 빈 배열 | a, b 값이 남았는지 읽기 |

서명된 검증 앱의 entitlements(`codesign -d --entitlements - --xml`):

- a: `application-identifier` = 팀 접두어 + `com.littlebit0.keychaincheck`, `keychain-access-groups` 없음.
- b, c: 같은 `application-identifier`, `keychain-access-groups` 빈 배열.

통과 기준: c 실행 결과에 기본·LMS 옵션 모두 a, b 값이 남아 있으면 업데이트 설치 뒤 값이 유지된 것입니다.

## 진행 상태 (2026-11-19)

- 검증 앱 a, b, c 빌드와 서명 확인: 완료.
- iPhone 17(실기기)에 a 설치: 완료. App Store Daily 4.2.0은 설치 상태 그대로이며 건드리지 않았습니다.
- a 실행: 실패. 기기가 잠겨 있어 실행이 거부됐습니다(`FBSOpenApplicationErrorDomain error 7`, Locked). 따라서 값 쓰기와 업데이트 뒤 읽기는 아직 하지 않았습니다.

## 확인하지 못한 것

- 업데이트 설치 뒤 값 유지(위 a → b → c). 기기 잠금 해제 후 실행하면 됩니다.
- App Store 배포 서명으로의 실제 업데이트. 검증 앱은 개발 서명이며 `get-task-allow`가 켜져 있습니다.
- 실제 Daily 앱의 로그인·PIN 화면 흐름. 검증 앱은 같은 플러그인과 같은 옵션만 재현합니다.
- 검증 앱에는 앱 그룹·Sign in with Apple entitlements가 없습니다. 기본 그룹이 앱 ID라는 점은 위 Apple 문서 순서로 판단했습니다.

## 참고

- [Sharing access to keychain items among a collection of apps](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
- [kSecAttrAccessGroup](https://developer.apple.com/documentation/security/ksecattraccessgroup)
