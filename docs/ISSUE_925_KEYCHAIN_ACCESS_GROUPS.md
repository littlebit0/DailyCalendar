# 이슈 #925 기록: iOS `keychain-access-groups` 빈 배열

기준: `main` `bd0f3bc41` (2026-11-19). 코드·entitlements 변경 없음. 서명 빌드 기록과 Apple 공식 문서를 근거로 마무리했고, 실기기 업데이트 확인은 하지 않았습니다.

## 서명 빌드 기록

4.2.0 App Store용 ipa를 `codesign -d --entitlements - --xml`로 확인했습니다.

- `Runner.app`: `keychain-access-groups`는 빈 배열 그대로입니다. Xcode가 값을 채우지 않았습니다. `application-identifier`(팀 ID + `com.littlebit0.daily`)가 함께 있고, 앱 그룹은 `group.com.littlebit0.daily.widgets`입니다.
- `DailyWidgets.appex`: `keychain-access-groups` 키가 없습니다.

## entitlements 이력

| 범위 | `Runner.entitlements`의 `keychain-access-groups` |
| --- | --- |
| 2.7.1 이전 | 키 없음 |
| 2.7.1(`c48350c1c`, 2026-07-21)부터 현재까지 | 빈 배열 |

## 앱의 보안 저장 사용 방식

- 기본 옵션 `const FlutterSecureStorage()`: 설정(`lib/core/settings/settings_repository.dart`), Google 인증(`lib/core/sync/google_drive_auth_service.dart`), LMS 웹 세션, 분석 설정.
- LMS 계정: `IOSOptions(synchronizable: false, accessibility: KeychainAccessibility.unlocked_this_device)` (`lib/core/lms/lms_credentials_store.dart`).
- 플러그인(`third_party/flutter_secure_storage_darwin`)은 `groupId`가 있을 때만 `kSecAttrAccessGroup`을 지정합니다. 앱은 `groupId`를 쓰지 않습니다.

## 근거와 판단

- Apple 문서상 앱의 접근 그룹 목록은 `keychain-access-groups` 항목, 앱 ID(팀 ID + 번들 ID), 앱 그룹 순서입니다. 접근 그룹을 지정하지 않고 저장한 항목은 이 목록의 첫 그룹에 들어갑니다.
- 배열이 비어 있거나 키가 없으면 첫 그룹은 앱 ID입니다. 따라서 2.7.1 이전(키 없음)과 이후(빈 배열) 모두 항목은 앱 ID 그룹에 있습니다.
- 앱 ID는 같은 팀·같은 번들 ID로 서명한 업데이트에서 바뀌지 않습니다. 키체인 항목은 앱 데이터 컨테이너가 아니라 시스템 키체인에 접근 그룹 단위로 저장되므로, 업데이트 설치 뒤에도 같은 그룹으로 읽힙니다.
- 결론: 현재 설정은 업데이트 뒤 로그인·PIN 등 보안 저장값 유지에 영향이 없다고 판단합니다.

## 주의: 이 배열에 그룹을 추가하지 말 것

`keychain-access-groups`에 이름 있는 그룹(예: 팀 ID + 공유 그룹 이름)을 넣으면 그 그룹이 목록의 첫 항목이 되어 기본 그룹이 바뀝니다. 그 뒤 `groupId` 없이 저장하는 새 항목은 새 그룹에 들어가고, 앱 ID 그룹에 있던 기존 값과 갈라집니다. 읽기 방식에 따라 기존 로그인·PIN이 보이지 않거나 값이 두 벌로 남을 수 있습니다. 키체인 공유가 필요해지면 기존 항목을 옮기는 처리와 함께 설계해야 합니다.

## 확인하지 못한 것

- 실기기에서 업데이트 설치 뒤 값이 유지되는지는 확인하지 않았습니다. 사용자 결정(2026-11-19)으로 생략하고 위 문서 근거로 마무리했습니다.

## 참고

- [Sharing access to keychain items among a collection of apps](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps): 접근 그룹 목록 순서와 기본 그룹
- [kSecAttrAccessGroup](https://developer.apple.com/documentation/security/ksecattraccessgroup): 그룹 미지정 시 첫 그룹에 저장
- [Keychain Access Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/keychain-access-groups)
