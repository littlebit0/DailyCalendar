# Apple 빌드 설정

Daily는 이미 Flutter iOS/macOS 타깃을 포함하고 있습니다. 다만 Apple 플랫폼 산출물을 만들려면 소스에 커밋할 수 없는 로컬 도구, OAuth, 서명 설정이 필요합니다.

현재 App Store 제출 준비 기준은 iOS/macOS 모두 `3.4.0 (3.4.0)`입니다.
서명된 IPA/PKG는 `dist/transporter-upload/3.4.0` 폴더 하나에 모으며,
GitHub의 unsigned IPA/DMG와 구분합니다. 생성만으로 업로드·심사 승인을 의미하지 않습니다.

## 현재 앱 ID

- iOS 번들 ID: `com.littlebit0.daily`
- macOS 번들 ID: `com.littlebit0.daily`
- iOS/macOS 위젯 번들 ID: `com.littlebit0.daily.widgets`
- 앱 버전 및 빌드: `3.4.0 (3.4.0)`
- 최소 iOS 버전: `15.0`

## 필요한 로컬 도구

1. Xcode 라이선스와 최초 실행 설정을 완료합니다.

   ```sh
   sudo xcodebuild -license
   sudo xcodebuild -runFirstLaunch
   ```

2. Flutter SDK를 설치하거나 `PATH`에 노출합니다.

   현재 프로젝트는 Dart `^3.11.5`를 요구하므로 Dart 3.11 이상이 포함된 Flutter 버전을 사용합니다.

3. CocoaPods는 현재 Swift Package Manager 빌드에는 필요하지 않습니다. 레거시 Pod 기반 워크플로를 사용할 때만 설치합니다.

   ```sh
   sudo gem install cocoapods
   ```

4. 도구 상태를 확인합니다.

   ```sh
   ./tool/flutter.sh doctor -v
   ./tool/flutter.sh pub get
   ./tool/flutter.sh test
   ```

## Google 로그인과 Drive 동기화

앱은 Google Drive AppData에 동기화 데이터를 저장합니다. Android, web, Windows OAuth client는 `docs/GOOGLE_DRIVE_SYNC_SETUP.md`에 정리되어 있습니다.

Google Cloud에서 다음 OAuth client를 확인하거나 생성합니다.

- iOS client: 번들 ID `com.littlebit0.daily`
- macOS client: 번들 ID `com.littlebit0.daily`
- 기존 Web client는 `GOOGLE_SIGN_IN_SERVER_CLIENT_ID`로 계속 사용 가능

iOS는 현재 `ios/Runner/GoogleService-Info.plist`와 `ios/Runner/Info.plist`에 아래 client가 연결되어 있습니다.

- Client ID: `234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa.apps.googleusercontent.com`
- Reversed client ID: `com.googleusercontent.apps.234127810480-l6i9pnoq4hpg6as12n7g1q5h0cak39oa`
- Server client ID: 없음. iOS에는 다른 프로젝트의 `SERVER_CLIENT_ID`를 넣지 않습니다.

macOS 네이티브 GoogleSignIn 경로는 현재 `macos/Runner/GoogleService-Info.plist`와 `macos/Runner/Info.plist`에 아래 client가 연결되어 있습니다. 기본 macOS 로그인은 아래 네이티브 client가 아니라 Desktop OAuth 브라우저 경로를 사용합니다.

- Client ID: `424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com`
- Reversed client ID: `com.googleusercontent.apps.424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq`

iOS와 macOS의 `GoogleService-Info.plist` 및 `Info.plist`에는 현재 Google 로그인용 client ID와 reversed client ID URL scheme이 체크인되어 있습니다. Google Cloud에서 새 OAuth client를 만들면 두 plist의 `CLIENT_ID`, `REVERSED_CLIENT_ID`, `GIDClientID`, `CFBundleURLSchemes` 값을 함께 교체해야 합니다.

실행/빌드 시 client ID를 전달합니다.

```sh
./tool/flutter.sh run -d macos \
  --dart-define=GOOGLE_MACOS_CLIENT_ID="<macos-client-id>" \
  --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID="<web-client-id>"

./tool/flutter.sh run -d ios \
  --dart-define=GOOGLE_IOS_CLIENT_ID="<ios-client-id>"
```

Apple OAuth client에는 reversed client ID도 함께 생성됩니다. Google 로그인 콜백을 받으려면 아래 파일에 URL scheme을 추가해야 합니다.

- `ios/Runner/Info.plist`
- `macos/Runner/Info.plist`

plist 항목 형태:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.example-reversed-client-id</string>
    </array>
  </dict>
</array>
```

Android, web, Windows client ID를 iOS/macOS용으로 재사용하면 안 됩니다.

macOS 기본 로그인 경로는 브라우저 기반 Desktop OAuth입니다. 이 경로는 keychain sharing entitlement 없이도 로컬 릴리스 빌드를 만들 수 있습니다.

네이티브 macOS GoogleSignIn SDK를 사용하려면 keychain sharing entitlement가 필요합니다. 이 entitlement는 Apple 개발 서명 인증서가 없으면 로컬 빌드를 막기 때문에 기본 릴리스 entitlements에는 포함하지 않습니다. 네이티브 GoogleSignIn을 Apple Developer Team 서명으로 배포할 때만 다음 항목을 추가합니다.

```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
</array>
```

브라우저 기반 OAuth를 명시적으로 쓰고 싶다면 Desktop OAuth client ID를 전달합니다. Desktop OAuth client secret은 Google 설치형 앱 흐름에서 선택값이지만, 현재 Daily Desktop OAuth client는 token exchange에서 secret을 요구하므로 배포 빌드에는 함께 전달합니다. secret 값은 Git에 커밋하지 말고 로컬 secret 또는 CI secret으로만 주입합니다.

```sh
./tool/flutter.sh run -d macos \
  --dart-define=GOOGLE_MACOS_AUTH_MODE=desktop \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>"

# Optional:
./tool/flutter.sh run -d macos \
  --dart-define=GOOGLE_MACOS_AUTH_MODE=desktop \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="<desktop-client-id>" \
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="<desktop-client-secret>"
```

## 빌드 명령

`./tool/flutter.sh`는 Flutter SDK와 Pub cache를 프로젝트 상위 폴더에서 찾고, Apple 코드서명이 `Documents` 폴더의 확장 속성에 걸리지 않도록 `build`를 `/tmp/daily-flutter-build`로 연결합니다.

iOS 시뮬레이터 빌드:

```sh
./tool/flutter.sh build ios --simulator \
  --dart-define=GOOGLE_IOS_CLIENT_ID="<ios-client-id>"
```

macOS 릴리즈 앱:

```sh
./tool/flutter.sh build macos --release \
  --dart-define=GOOGLE_MACOS_CLIENT_ID="<macos-client-id>" \
  --dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID="<web-client-id>"
```

iOS 실제 기기 또는 App Store archive:

```sh
./tool/flutter.sh build ios --release \
  --dart-define=GOOGLE_IOS_CLIENT_ID="<ios-client-id>"
```

실제 기기, TestFlight, App Store, Developer ID, notarized macOS 배포에는 Xcode에서 Apple Developer Team과 서명 인증서/프로비저닝 프로파일을 맞춰야 합니다.

Personal Team으로 실제 iPhone 개발 설치를 만들려면 iPhone을 Mac에 연결하고, 기기에서 이 컴퓨터를 신뢰한 뒤, Xcode가 해당 UDID를 팀에 등록할 수 있어야 합니다. 기기가 등록되어 있지 않으면 Xcode archive가 `Your team has no devices from which to generate a provisioning profile` 오류로 실패합니다.

Time Sensitive Notifications capability는 Apple Personal Team에서 provisioning할 수 없습니다. Daily의 기본 일정 알림은 이 capability 없이도 표준 Notification Center 알림으로 동작하므로, Personal Team 개발 설치와 일반 빌드 가능성을 위해 릴리스 entitlements에는 포함하지 않습니다.

## 참고

- macOS entitlements에는 Drive API 호출을 위한 sandbox network client 권한이 포함되어 있습니다.
- 네이티브 macOS GoogleSignIn SDK는 keychain access group이 없으면 `keychain error`를 반환합니다. 현재 기본 macOS 경로인 Desktop OAuth는 이 권한을 사용하지 않습니다.
- Google 로그인 창이 열린 뒤 앱으로 돌아오지 않으면 reversed client ID URL scheme이 없거나 잘못된 상태입니다.
