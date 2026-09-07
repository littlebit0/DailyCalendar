# Daily Apple App Store Submission

## Current Preparation: 3.4.0

최종 갱신: 2026-09-07
준비 버전: iOS `3.4.0 (3.4.1)`, macOS `3.4.0 (3.4.0)`
대상: iOS/iPadOS 및 macOS

- 앱 번들 ID: 두 플랫폼 모두 기존 `com.littlebit0.daily` 유지
- 위젯 번들 ID: 기존 `com.littlebit0.daily.widgets` 유지
- 서명 팀: `A6Y73X2ZLS`
- 제출용 파일은 아래 한 폴더에 모으며 GitHub 공개 릴리스에는 올리지 않는다.
  `dist/transporter-upload/3.4.0`
- iOS: `Daily-iOS-AppStore-3.4.0-build-3.4.1.ipa`
- macOS: `Daily-macOS-AppStore-3.4.0-build-3.4.0.pkg`
- 이번 작업은 파일 생성까지이며 Transporter 업로드·App Store Connect 빌드
  선택·심사 제출·승인 완료를 의미하지 않는다.
- 현재 App Store 공개 버전과 제출 상태는 이번 작업에서 확인하지 않았다.
- 최신 변경사항은 [3.4.0 릴리스 노트](RELEASE_NOTES_3.4.0.md)를 기준으로 한다.
- Windows에는 최신 변경사항이 미적용 상태이며 이번 제출 대상이 아니다.

### Build Status

- 2026-09-07 모바일 분류 순서 수정본으로 iOS 아카이브/서명 IPA를 다시
  생성했다. 기존 iOS 제출용 IPA는 삭제하고 같은 폴더에서 교체했다.
  업로드 이력을 확인하지 못해 이전 빌드와의 중복을 피하도록 제출용 앱·위젯의
  빌드번호만 `3.4.1`로 높였다. 앱 버전과 번들 ID는 유지한다.
  macOS PKG는 다시 만들거나 변경하지 않았다.
- iOS/macOS Release 아카이브 생성과 앱·위젯 버전/번들 ID 검증은 완료했다.
- 최종 서명 IPA/PKG 생성 완료. 최초 Apple 계정 세션 만료 오류는 2026-09-07
  사용자 재로그인 후 해결됐으며, 두 플랫폼 모두 App Store 내보내기가 성공했다.
- 앱·위젯 Apple Distribution 서명, 위 플랫폼별 버전·빌드, 기존 번들 ID,
  배포 프로파일과 서명 인증서 일치, `codesign --verify --deep --strict` 확인.
- macOS PKG는 Mac App Store Installer 인증서로 서명됐으며 앱·위젯은
  arm64/x86_64 universal이다. 실행 파일 없는 리소스 번들 16개는 미서명 상태다.
- 최종 파일과 내보낸 원본의 SHA-256 일치 확인:
  - IPA (27,603,492 bytes): `0e49865d50e3c64ab873513f4ec4e4f19cde60efbaf8bc1a0db9cbc884d27ad8`
  - PKG: `3f1cb0b963c9a6b29b5c3811bfa3ed28b4f8f70c5a7fe18cf2861f7eafdf55f7`
- 파일만 생성했으며 Transporter 업로드, App Store Connect 처리·심사 결과는
  아직 확인하지 않았다. 기존 설치 앱과 사용자 데이터는 변경하지 않았다.
- 아카이브는 `dist/appstore-archives/3.4.0`에 보관한다. 개발용 서명 아카이브나
  공개 릴리스의 unsigned 파일을 App Store 제출용으로 사용하지 않는다.
  최신 iOS 아카이브는 `Daily-iOS-3.4.0-build-3.4.1.xcarchive`이다.

## Historical Record: 3.0.1

아래 내용은 2026-08-03의 과거 제출 기록이다. 현재 출시 상태나 3.4.0의
개인정보·권한 답변으로 그대로 사용하지 않는다.

최종 갱신: 2026-08-03
제출 버전: `3.0.1 (3.0.1)`
대상: iOS/iPadOS 및 macOS

## App Store Connect 상태

- 앱 이름: `DailyCalendar`
- iOS/macOS 앱 번들 ID: `com.littlebit0.daily`
- iOS/macOS 위젯 번들 ID: `com.littlebit0.daily.widgets`
- iOS App Store 공개 버전: `2.7.1`
- iOS 3.0.1 IPA: Transporter 업로드 및 Apple 처리 완료
- macOS 3.0.1 PKG: Transporter 업로드 및 Apple 처리 완료
- 한국어 설명, 업그레이드 사항, 지원 URL과 심사 메모: 3.0.1 기준 저장

## 제출 파일

- iOS:
  `dist/transporter-ios-3.0.1/Daily-iOS-AppStore-3.0.1-build-3.0.1.ipa`
- macOS:
  `dist/transporter-macos-3.0.1/Daily-macOS-AppStore-3.0.1-build-3.0.1.pkg`

## 최종 제출 순서

1. iOS 3.0.1 페이지에서 빌드 `3.0.1 (3.0.1)` 선택
2. macOS 3.0.1 페이지에서 빌드 `3.0.1 (3.0.1)` 선택
3. 수출 규정 질문에서 Daily가 독자 암호화 알고리즘을 구현하지 않았음을 기준으로 응답
4. iOS와 macOS를 각각 심사에 추가
5. 앱 심사 제출 초안에서 두 플랫폼과 버전을 다시 확인
6. 최종 제출

## 심사 핵심 설명

- `로컬로 시작`을 선택하면 계정 없이 전체 기본 캘린더 기능을 심사할 수 있다.
- Sign in with Apple은 Google 로그인을 요구하지 않는다.
- Google 로그인은 Google Calendar 가져오기와 Drive AppData 백업·동기화를 위한 선택 기능이다.
- Google Drive 일반 파일은 읽거나 수정하지 않는다.
- 기존 Google 세션의 조용한 복원에 실패해도 Apple/local 모드를 차단하거나
  자동으로 대화형 로그인 창을 열지 않는다.
- 광고, IDFA, 광고 측정, 데이터 브로커 및 앱·웹사이트 간 추적을 사용하지 않는다.

플랫폼별 전체 메모는 `docs/APP_REVIEW_NOTES_3.0.1.md`, 사용자에게 표시할 변경
사항은 `docs/APP_STORE_WHATS_NEW_3.0.1.md`를 사용한다.

## 개인정보 및 권한

- 캘린더 권한: 사용자가 외부 캘린더 가져오기를 선택할 때만 요청
- 알림 권한: 일정 알림, 아침 브리핑과 D-day 알림
- AlarmKit 권한: 지원 iOS에서 사용자가 일정 알람 기능을 사용할 때 요청
- App Privacy의 수집 데이터는 앱 기능 목적으로만 표시
- 모든 추적 관련 응답은 `아니요`

## 출시 설정

- 무료 앱
- 자동 출시
- 모든 사용자에게 즉시 업데이트 출시
- 기존 평점 유지

## 제출 후 확인

- 두 플랫폼의 상태가 `심사 대기 중`으로 변경됐는지 확인
- App Review 메시지와 이메일 모니터링
- 승인 후 iOS 업데이트 및 macOS 최초 App Store 설치 검증
- Google 로그인, Apple 로그인, 로컬 모드, 위젯과 동기화 smoke test
