# Agent Memory

This file is a handoff note for agents working on Daily. It records the current
release state, completed work, release status, and safe next steps. Do not add
OAuth client secrets, GitHub tokens, signing certificates, provisioning
profiles, keystore passwords, or private keys to this file.

## Current Platform Status: 3.4.0 (2026-09-07)

- 사용자 명시: 지금까지의 최신 적용사항은 **Windows 미적용 상태**다.
  공유 Flutter 코드에 변경이 있거나 Windows 대상 자동 테스트가 통과했더라도
  Windows 적용 완료로 기록하지 않는다. Windows 에이전트의 별도 반영,
  네이티브 빌드, 실제 Windows 검증과 업데이트가 필요하다.
- iOS/macOS/Android에서 진행한 드래그·순서·완료 표시·더블클릭, 빠른 보기,
  날짜 헤더·스크롤·설정 및 플랫폼별 수정사항이 Windows 후속 확인 범위다.
  Android 전용 AlarmManager/위젯이나 Apple 전용 Siri/AlarmKit을 Windows에
  동일 API로 구현한다는 의미는 아니다. 기존 플랫폼 경계를 유지한다.
- Windows 공개 설치본은 3.3.1이며 이번 작업에서 3.4.0 Windows 설치 파일을
  발행하지 않는다. 소스 버전 3.4.0 승격을 Windows 기능 적용으로 간주하지 않는다.
- 배포 작업 순서: README/릴리스 노트 갱신 → 커밋/푸시 → GitHub 3.4.0
  릴리스 → iOS/macOS Transporter 서명 산출물 생성. 서명 파일은 공개하지 않고
  로컬 `dist/transporter-upload/3.4.0` 폴더에 IPA/PKG를 나란히 보관한다.

Historical app-version notes below `2.0.0` were intentionally removed on
2026-06-06 at the user's request.

## 2026-08-27 Windows Schedule and Settings Motion Fix

- Windows week/day schedule time scrolling now uses the same shared
  `SmoothMouseWheelScrollController` and `ScrollPosition` as the vertical
  month calendar. Mouse-wheel targets accumulate during the existing 160 ms
  `easeOutCubic` transition, clamp at the time-axis boundaries, and handle an
  immediate reverse input without leaving a stale animation target. Vertical
  schedule scrolling does not change the selected day or week.
- The shared controller was extracted to
  `lib/core/widgets/smooth_mouse_wheel_scroll_controller.dart`. Vertical month
  navigation keeps its previous initial offset, extent replacement, and
  disposal behavior. Schedule views select the smooth controller only on
  Windows; other platforms keep the ordinary `ScrollController`, touch/trackpad
  behavior, and the 07:00 initial position.
- The Windows settings controls had not lost their animation widgets. Their
  selected values were only published after roughly 30 asynchronous
  SharedPreferences writes, so the first visual frame was delayed until disk
  persistence completed. `SettingsPage` now keeps a Windows-only pending UI
  value so the existing 150 ms capsule `AnimatedAlign` and Material switch
  transitions begin immediately.
- Windows whole-settings saves are serialized. The global settings provider,
  native calendar-widget listeners, and backups receive successful values in
  input order; a failed newest save clears the pending UI and returns to the
  last successfully persisted provider value. Non-Windows save ordering and
  settings behavior are unchanged.
- Verification passed focused schedule/controller tests (14 schedule tests,
  including accumulated, reverse, boundary, date-invariance, and non-Windows
  cases), the Windows settings mid-animation/queued-save/rollback test, the
  existing Windows page-wheel test, full Flutter analysis, all 272 Flutter
  tests, formatting, and `git diff --check`.
- The isolated `%LOCALAPPDATA%\Programs\DailyCalendar Test\DailyCalendar
  Test.exe` was rebuilt and reinstalled as Profile/AOT (`IsDebug=false`,
  `data/app.so` present, no `kernel_blob.bin`). GUI smoke testing confirmed the
  week schedule time axis scrolls and the week-start capsule and lunar switch
  change visibly; both test settings were restored. The test app is left open
  on the Screen and Calendar settings page for physical testing.
- Production `C:\Program Files\Daily\DailyCalendar.exe` remained stopped and
  unchanged with SHA-256
  `7F986A716C0D6F7E7A980CA00055AD0B1E56C2B3D2BA8A457EE1DFAB0D0B58A6`.
  These changes have not been committed or pushed.

## 2026-08-27 Windows Calendar Profile/AOT Performance Fix

- The previously installed `DailyCalendar Test` was a Flutter Debug/JIT
  bundle: it contained a roughly 91 MB `kernel_blob.bin`, had no `app.so`, and
  exactly matched the Debug build. Its calendar frame rate was therefore not
  representative of the distributed Windows app.
- Windows horizontal month, week, and day PageViews now keep page changes
  local while an animation is running. The selected-date and visible-month
  providers are committed once after the outer PageView has fully settled.
  Nested schedule scroll notifications are ignored, and a post-frame
  scrolling/revision check prevents provider rebuilds between queued wheel
  animations. Other platforms retain their previous midpoint commit timing.
- `eventsInRangeProvider` is now `autoDispose.family`, so Drift range streams
  for calendar pages that have actually left the PageView cache are cancelled
  instead of accumulating for the entire app session.
- Debug and Profile builds both compile with `DAILY_TEST_EDITION` and use the
  isolated `DailyCalendar Test` window, executable metadata, widget directory,
  application-support directory, notification AUMID, and notification GUID.
  Release continues to use the production `DailyCalendar` identities.
- `tool/run_windows_test.ps1` now defaults to Profile but accepts explicit
  `-BuildMode Debug` or `-BuildMode Profile`. For Profile it requires
  `data/app.so`, rejects `kernel_blob.bin`, requires `IsDebug=false`, and keeps
  the existing exact-path, production-hash, staging, backup, and rollback
  guards. Windows auto-update and the production analytics endpoint remain
  Release-only.
- The current side-by-side installation is the Profile/AOT bundle at
  `%LOCALAPPDATA%\Programs\DailyCalendar Test\DailyCalendar Test.exe`. It is
  running as `DailyCalendar Test`, reports `IsDebug=false`, contains `app.so`,
  and has no Debug kernel blob. Production
  `C:\Program Files\Daily\DailyCalendar.exe` remained stopped and unchanged;
  its verified SHA-256 is
  `7F986A716C0D6F7E7A980CA00055AD0B1E56C2B3D2BA8A457EE1DFAB0D0B58A6`.
- Verification passed Flutter analysis, all 269 Flutter tests, focused
  Windows wheel/provider-settle tests, test/production identity tests, updater
  tests, PowerShell parser validation, Profile build/install checks, an actual
  Release AOT build with unchanged `DailyCalendar` metadata, and GUI smoke
  navigation for next/previous week plus next/previous month by mouse wheel.
  The app is left open on the August 2026 horizontal month view for physical
  mouse/display testing.
- These changes have not been committed or pushed.

## 2026-08-27 Android Horizontal Month Label Parity

- Compact Android phones using horizontal month navigation now reuse the
  vertical continuous-calendar `_MonthBoundaryLabel` instead of a separate
  small `labelLarge` caption. Both modes therefore show the localized month at
  34 px, weight 800, using the normal surface color and the same trailing
  divider.
- The Android-only visibility rule and the existing
  `android-horizontal-month-indicator` test key remain unchanged. Windows and
  Apple layouts do not gain this extra compact-phone label.
- Widget coverage verifies the shared typography, color, and divider at a
  430x932 Android viewport.

## 2026-08-27 Windows Mouse Wheel Calendar Paging

- Horizontal month mode plus the week/day PageViews now normalize Windows
  mouse-wheel input into adjacent-page transitions. A short burst of raw
  vertical-wheel or horizontal-tilt signals from one physical detent produces
  one previous/next page animation, and separate bursts are animated in order
  instead of repeatedly retargeting the same animation.
- A Windows-only Listener inside each PageView item claims mouse pointer
  signals before PageView's own horizontal pixel scrolling can process them.
  This prevents the default pixel jump from cancelling or competing with the
  custom page animation. Nested vertical schedule scrolling still wins signal
  resolution and continues to scroll time without changing the day/week.
- Trackpad pan/zoom drag and fling remain on the existing PageView gesture
  path. Starting a trackpad gesture cancels a pending Windows wheel burst so a
  delayed wheel transition cannot fire during the gesture. macOS and other
  platforms retain their previous mouse/trackpad handling.
- Regression coverage sends real Windows pointer signals for horizontal week
  and day navigation, split vertical and horizontal month-wheel bursts,
  PageView pixel-scroll suppression, nested schedule scrolling, reverse tilt,
  and pending-wheel cancellation by a trackpad fling. The existing macOS
  PageView/trackpad integration test remains unchanged in behavior.
- Final integration verification passed `flutter analyze --no-pub`, all 64
  widget tests, and all 268 Flutter tests.

## 2026-08-27 Android/Windows Local Test Install

- `Daily_API_35` now uses host GPU rendering and a 120 Hz virtual display.
  The previous emulator app and its test-only data were removed, the 3.3.1
  Release APK was installed cleanly, and
  `com.littlebit0.dailycalendar/.MainActivity` was launched successfully.
- The isolated Windows Debug edition was installed at
  `%LOCALAPPDATA%\Programs\DailyCalendar Test\DailyCalendar Test.exe` with a
  current-user Start Menu shortcut named `DailyCalendar Test`. Its running
  window, ProductName, FileDescription, and InternalName all identify it as
  `DailyCalendar Test`; its application-support directory is separate from
  production.
- Production `C:\Program Files\Daily\DailyCalendar.exe` remained version
  `3.0.1+302`, was not launched, and its timestamp/hash were preserved by the
  test installer check.
- After the calendar paging, Android month-label, and onboarding fixes, the
  current Release APK was installed with `adb install -r` so emulator data was
  preserved. The isolated Windows Debug bundle was rebuilt and reinstalled.
  Android resumed in `MainActivity` at 120 Hz and `DailyCalendar Test` resumed
  from its separate current-user install; production Daily remained stopped.
- Verification: Flutter analysis passed, the 8 focused Windows test-identity,
  updater, and installation-configuration tests passed, Debug built with the
  test identity, Release built with the unchanged `DailyCalendar` identity,
  and `git diff --check` passed.

## 2026-08-26 Windows Side-by-Side Debug Test Edition

- Windows Debug builds use the isolated visible identity
  `DailyCalendar Test` for the executable version resource, Flutter window,
  tray tooltip/menu, native dialogs, and Flutter application title. Windows
  Release builds keep the production identity `DailyCalendar` unchanged.
- Debug notification initialization uses app name `DailyCalendar Test`, AUMID
  `Personal.Daily.Calendar.Test`, and GUID
  `0734c50a-0934-4e91-ad45-58f8d2ea41d5`. Release keeps its existing app name
  `DailyCalendar`, AUMID `Personal.Daily.Calendar`, and GUID
  `4c124e1f-e041-4f68-aa1e-9ee8ec1a4fb7`.
- The Windows native widget bridge stores Debug actions under
  `%LOCALAPPDATA%\DailyCalendar Test`; Release continues to use
  `%LOCALAPPDATA%\DailyCalendar`. The executable ProductName separation also
  gives Flutter application-support data a separate Debug directory.
- The Windows automatic updater is enabled only for Release builds. Debug and
  profile builds return before checking or installing an update.
- `tool/run_windows_test.ps1` explicitly builds Debug, verifies the Debug
  executable identity, stages the bundle under
  `%LOCALAPPDATA%\Programs\DailyCalendar Test`, renames only the copied entry
  executable to `DailyCalendar Test.exe`, and creates the current-user Start
  Menu shortcut `DailyCalendar Test.lnk`. The script validates exact targets,
  rejects reparse-point test directories, refuses targets under
  `C:\Program Files\Daily`, preserves a previous test bundle transactionally,
  refuses to replace a running test bundle, and verifies the production
  executable hash did not change. Use `-NoLaunch` when installation without an
  automatic launch is desired.
- Production `C:\Program Files\Daily` must never be used as a Debug target.
  Building/tests alone do not install or launch either edition.

## 2026-08-26 Cross-Platform Calendar Widget Contract

- The shared Flutter owner for calendar surfaces is now
  `CalendarWidgetService` in
  `lib/core/widgets/calendar_widget_service.dart`. It builds one localized
  schedule/Todo/theme snapshot for Apple WidgetKit, Android home widgets, and
  the Windows calendar surface. `AppleWidgetService`,
  `AppleWidgetSnapshotBuilder`, and `AppleWidgetTodoAction` remain as thin
  compatibility names, so the existing Apple behavior and native contract are
  preserved without editing Apple platform files.
- Platform channels use the same method and payload contract:
  - iOS/macOS: `daily/apple_widgets` (unchanged)
  - Android: `daily/android_widgets`
  - Windows: `daily/windows_widgets`
  - Flutter -> native: `updateSnapshot(Map)`, `pendingTodoActions()`, and
    `acknowledgeTodoActions({tokens: List<String>})`
  - native -> Flutter: `todoActionsChanged`
- A pending Todo action is `{token, eventId, completed}`. Native surfaces must
  return the base `eventId`, not an occurrence-only display ID. Flutter applies
  actions through `EventCommandService`, acknowledges missing/deleted events
  and successful actions, stops at the first mutation failure, refreshes the
  surface, records the allowlisted widget analytic, and invalidates visible
  calendar streams. Queued actions are checked at app start and resume as well
  as after the native callback.
- The shared snapshot keys remain compatible with Apple:
  `generatedAt`, `localeTag`, `themeMode`, `monthTitle`, `weekTitle`,
  `weekStartsOnMonday`, `monthDays`, `todayTitle`, `todayEvents`,
  `todayRemainingCount`, `scheduleEvents`, and `ddays`. Event rows keep both
  display `id` and base `eventId`, plus completion, color, timing, and all-day
  state where applicable. `localeTag` is the locale already resolved from the
  Daily language setting, so Android and Windows native surfaces must use it
  for weekday labels, empty states, and other native-only copy instead of
  independently selecting the OS language. Existing Apple native decoders
  ignore this additive field and remain compatible.
- Widget refreshes are no longer Apple-gated. Startup, resume, event mutation,
  Drive restore, category/settings reset, sign-out, and theme changes target
  the current OS channel. Siri/App Intents/Signal voice remain Apple-specific.
- Android/iOS/macOS/Windows now pass the common pointer-page-navigation gate;
  touch physics are unchanged. Windows quick-Todo columns use the same
  width-adaptive desktop calculation as macOS. The Windows notification
  initialization display name is `DailyCalendar`; the existing internal
  AppUserModelID and GUID remain unchanged for compatibility.
- This shared change does not alter the existing 120 Hz/touch tuning,
  biometric flow, adjacent-month dates, Drive v2 model, Windows updater, or
  installer.
- Verification on Windows:
  - `flutter analyze --no-pub`: passed with no issues.
  - `flutter test --no-pub`: all 258 tests passed.
  - Android debug Kotlin compilation and APK assembly passed.
  - `flutter build apk --release --no-pub`: produced the 3.3.1
    `DailyCalendar` phone-only APK.
  - `flutter build windows --release --no-pub`: produced
    `DailyCalendar.exe`; the native runner also passed `/W4 /WX` with no
    warnings or errors.
- The PowerShell Flutter wrapper now discovers the repository-local Android
  SDK and Android Studio JDK used by this Windows workspace. This keeps the
  already-installed Android toolchain usable without hard-coding a missing JDK.
- Apple native files were intentionally not changed. A later Mac/iPhone build
  should still smoke-test the preserved `daily/apple_widgets` bridge after
  pulling this shared refactor.

## 2026-08-17 App Store Transporter 3.1.0 Build

- Raised the shared visible app version and every iOS/macOS app and widget
  target to `3.1.0 (3.1.0)`. Android and Windows packaging settings were not
  changed in this Apple submission task.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub` (165 tests)
  - iOS App Store archive and export
  - macOS release build, archive, and Mac App Store export
- Both exported applications use the `Cloud Managed Apple Distribution`
  certificate for team `A6Y73X2ZLS`. The macOS installer package also has a
  valid `3rd Party Mac Developer Installer` signature.
- Transporter-ready artifacts:
  - iOS: `dist/transporter-ios-3.1.0/Daily-iOS-AppStore-3.1.0-build-3.1.0.ipa`
  - macOS: `dist/transporter-macos-3.1.0/Daily-macOS-AppStore-3.1.0-build-3.1.0.pkg`
- SHA-256:
  - iOS: `39df26833295a034825a85a2d3fd0a631f6129b1225d9efcc8ba25f81e552cab`
  - macOS: `ff8510892d59d1996c94a98071ffab7e2bf3f5469d1757bcf085c6dbaeac824a`

## User Correction Memory

- 사용자가 강하게 항의하거나 욕설을 한 경우 표현 자체만 문제 삼지 말고, 바로
  직전에 에이전트가 무엇을 잘못 이해하거나 실행했는지 구체적으로 파악해 이
  문서에 재발 방지 사항으로 남긴다.
- 지적받은 작업을 임의로 다른 방식으로 대체하거나 롤백하지 않는다. 사용자의
  원래 목표, 현재 적용 상태, 해결하지 못한 부분을 분리해 확인한다.
- 사용자가 `대답만`, `작업하지 말고`라고 지시하면 파일 수정, 빌드, 설치 등
  실행 작업을 하지 않고 질문에만 답한다.

### 2026-08-15 LLM 버튼 처리 오류

- 사용자 요구는 LLM 버튼에서 나타나는 단축어 받아쓰기 화면을 실제 Siri 호출로
  교체하는 것이었다.
- 에이전트는 실제 Siri 호출 경로를 해결하지 못한 상태에서 사용자 승인 없이
  LLM 버튼을 기존 앱 내부 AI 입력 화면으로 롤백했다.
- 잘못된 동작을 제거하는 것과 이전 기능으로 되돌리는 것은 서로 다른 작업이다.
  목표 동작을 구현할 수 없다면 기존 동작을 임의로 변경하지 말고, 현재 상태와
  제약을 설명한 뒤 사용자 결정을 받아야 한다.
- 현재 LLM 버튼은 앱 내부 AI 입력 화면으로 롤백된 상태다. 사용자가 이를 잘못된
  조치로 명확히 지적했으며, 후속 변경은 별도 지시에 따라 진행한다.

## Current State

- Repository: `littlebit0/Daily`
- Local macOS path currently used:
  `/Users/kimhwi/Documents/Codex/2026-05-26/littlebit0-daily-https-github-com-littlebit0`
- Windows/Android handoff path used by the previous agent:
  `C:\Users\com\Documents\New project\.codex-tools\portfolio_repos\Daily`
- Branch: `main`
- Current visible app version in repo: `3.1.0 (3.1.0)`
- Current `pubspec.yaml` version has no `+` suffix.
- iOS/macOS App Store binaries use app version and build `3.1.0`.
- Android maps the shared release to integer version code `301`.
- Windows uses the required four-part package version `3.0.1.0`.
- Latest published release tag before this release work: `v2.7.1`.
- The next release tag is `v3.0.1`; confirm its workflow and assets after the
  release commit and tag are pushed.

## Project Rules Snapshot

- Daily is a real production app. Do not use temporary workarounds, fake data,
  placeholders, hard-coded behavior, silent feature removals, or feature
  regressions.
- Keep Windows, Android, macOS, and iPhone/iOS behavior aligned for calendar,
  sync, notification, auth, and settings flows.
- Do not commit OAuth secrets, signing material, provisioning profiles,
  Android keystores, GitHub tokens, or private credentials.
- User-facing release names must not expose Flutter `+` build suffixes.
- Read `AGENTS.md` before changing behavior.

## Cross-Platform Sync Rule

- Windows, Android, iPhone/iOS, and macOS must all read and write the same
  Google Drive AppData file set.
- Production OAuth clients should point at the same Google Cloud project /
  Drive AppData namespace. Current iPhone-aligned target uses project number
  `234127810480`.
- Normal production sync uses the v2 Google Drive AppData model:
  - `daily-sync-v2-event-{eventId}.json` per event.
  - `daily-sync-v2-settings.json` for settings.
  - Date-only fields for all-day events.
  - Tombstones for deletes.
  - Event-only uploads for local create/update/delete changes.
- Do not bring back the old monolithic whole-backup file for normal sync.
- Create/update/delete events should perform backup-only event sync.
- App start, sign-in, resume, and best-effort background/exit paths may restore
  remote state as needed.
- A backup-then-restore sync must back up first, wait about 3 seconds, then
  restore.

## 2.0.0+ Work History

- `2.0.0` moved Windows/Android to the shared Google Drive AppData v2 model.
  Release coordination rule: after sync-schema-changing work, do not publish
  only one platform family. Windows/Android artifacts should be uploaded
  together with Mac/iPhone artifacts when the shared sync schema changes.
- Android package identity is `com.littlebit0.dailycalendar`.
- Android/Windows were aligned to the iPhone-source Google Drive AppData
  project `234127810480`.
- Android Google Sign-In default server client uses the 234-project web client.
  Do not revert Android to the old Firebase project metadata.
- Windows uses the 234 Desktop OAuth client and needs its client secret from a
  local environment/config source. Never commit or print that secret.
- All-day event sync was repaired to use date-only semantics so cross-device
  all-day events do not shift by one or two days.
- The active sync backend is Google Drive v2. Firebase/Auth/Firestore legacy
  Dart code and dependencies were later removed from the shared project.

## 2.0.1 Store Prep

- GitHub Actions were added for platform installer generation.
- The `v2.0.1` GitHub release published Android APK, macOS DMG, unsigned iOS
  IPA, Windows ZIP, and SHA-256 sums.
- iOS remains unsigned in CI because Apple signing assets are not stored in the
  repo.
- Daily app icons were generated for iOS, macOS, and Android.
- A Daily-branded iOS launch image was generated.
- `docs/STORE_SUBMISSION.md` documents Apple store submission status.
- Apple archive creation works, but App Store IPA export is blocked until the
  Apple account has a usable App Store Connect provider, Apple Distribution
  certificate, and App Store provisioning profile.

## 2.0.2 Sync/Login Optimization

- Login/connect no longer runs duplicated initial restore/full sync work.
- Connect flow should start listeners, flush pending local v2 event files, then
  restore v2 remote data.
- `startListeningOnly()` must not run an automatic initial restore.
- Pending queued/DB-pending event IDs are flushed on startup/background so local
  changes cannot survive restart unsynced.
- Local startup must not open a Google account chooser automatically.
- Logout should not run a full backup-all/full-restore. It should make a short
  pending-change flush attempt, then clear account state.
- Account/auth and Drive API waits should be bounded; user-driven approval
  waits must be separate from short network/token timeouts.
- Dependency cleanup removed inactive Firebase/Firestore code, stale Android
  `google-services.json`, unused direct dependencies, and refreshed Android
  Gradle/Kotlin versions.
- Mac/iPhone agents must run Flutter dependency generation on macOS/iOS before
  the next Apple build so stale native plugin registration is removed.

## 2.0.3 Google Login Follow-Up

- User-driven browser/account/Drive permission approval waits were separated
  from short app-controlled network/token timeouts.
- Browser/account/Drive approval can wait longer, while silent auth, token
  exchange, userinfo, Drive API requests, and logout remain bounded.
- This prevents Windows loopback OAuth or Android Drive approval from timing
  out while the user is still approving.
- Mac/iPhone agents should mirror this distinction if any platform-specific
  auth wrapper has its own timeout.

## 2.0.4 Windows/Android Release

- `v2.0.4` was published after a Windows/Android follow-up release.
- Android/Windows shared month `PageView` uses faster page settling and
  adjacent page preparation.
- Wide month detail loading keeps the panel mounted instead of showing a large
  spinner during range reload.
- Settings notification test layout moves the send button below text on compact
  widths.
- Google Drive local-mode copy was shortened for Korean line breaks.
- Locked categories show a disabled lock icon instead of an apparently tappable
  delete icon.
- Google login hardening verifies Drive authorization immediately after
  Settings > Google login.
- Prompt-driven header requests can recover from an empty local session by
  re-entering sign-in before failing.
- Windows release ZIP staging excludes `.pdb`, `.lib`, and `.exp` files.
- Android/Windows chronic issues such as emulator storage limits, debug/release
  signature mismatch, Windows Computer Use pipe availability, and Windows ZIP
  debug-symbol leakage are platform-only phenomena and should not be treated as
  macOS/iOS defects.

## 2.0.4 Verification Snapshot

- Windows/Android `flutter analyze --no-pub` passed.
- Windows/Android `flutter test --no-pub` passed with 31 tests.
- Android debug APK was rebuilt with test-only build number `8`.
- Smaller x86_64 split APK installed and launched on `emulator-5554`.
- Android monthly swipe was visually settled by the 450 ms capture.
- Settings showed compact notification layout and disabled lock icon for the
  locked holiday category.
- Windows release build succeeded with `daily.exe` file/product version
  `2.0.4`.
- Refreshed Windows ZIP was about 14.4 MB and contained no `.pdb/.lib/.exp`
  entries.
- Windows visual screenshot validation could not be completed in that Codex
  session because Computer Use screenshot capture was unavailable.

## 2.0.4 Release Artifacts

- `dist/release-2.0.4/daily-android-2.0.4.apk`
  - versionName: `2.0.4`
  - versionCode: `8`
  - SHA-256:
    `18080e2fedebbc48a2e685e8d7a529930125b26e795c1af31fc8732b72385681`
- `dist/release-2.0.4/daily-windows-2.0.4.zip`
  - SHA-256:
    `5f465ed937a2afd9079ff7c62b78a68890bc11686073261031fcf4d042faec87`
- `dist/release-2.0.4/SHA256SUMS.txt`

## Mac/iPhone Next Work

- 2026-06-06 Mac/iPhone pass after pulling `be8c639`:
  - Removed pre-`2.0.0` handoff history from this file at the user's request.
  - Ran `./tool/flutter.sh pub get`; macOS generated plugin registration now
    reflects the Firebase/Firestore dependency cleanup.
  - iOS generated plugin registration was already clean.
  - Removed stale Firebase/Firestore-related SwiftPM pins from iOS/macOS
    `Package.resolved` files. The remaining pins are the GoogleSignIn-required
    AppAuth/AppCheck/GTM/GoogleUtilities/Promises set.
  - Settings > Google login now verifies Drive authorization once, then runs
    the initial pending-change flush/restore without asking for another
    interactive Drive permission prompt. This reduces duplicated consent work
    during login.
  - Verification passed: `./tool/flutter.sh analyze --no-pub`,
    `./tool/flutter.sh test --no-pub` with 31 tests, and iOS release
    no-codesign build with `--build-name=2.0.4 --build-number=8`.
  - Connected iPhone `김휘의 iPhone`
    (`415EDAF7-A303-50FD-8344-351D7BF59153`) was installed with the latest
    development-signed `2.0.4 (8)` build and launched successfully.
  - `./tool/run_macos.sh` initially failed because stale `/tmp/daily-flutter-build`
    macOS output still contained removed Firebase-era SPM artifacts such as
    `absl.framework`. Removing `/tmp/daily-flutter-build/macos` and rerunning
    fixed the issue.
  - macOS debug app was rebuilt, signed with
    `Apple Development: kimhee8953@naver.com (739BC896PZ)`, installed to
    `~/Applications/Daily.app`, launched successfully, and the process was
    observed running.
  - macOS UX test found that closing the last Daily window could leave the
    process running with no visible window. `macos/Runner/AppDelegate.swift`
    now terminates after the last window closes so relaunch returns to a normal
    visible app window.
  - iOS/macOS UI smoke found the chat send button appeared actionable while the
    input was empty. `ChatInputBar` now listens to text changes and disables
    the send button until non-empty text is present.
  - macOS Google desktop OAuth token exchange failed after browser login. The
    auth service now reads macOS Desktop OAuth config from
    `~/Library/Application Support/Daily/google_desktop_oauth.json` (or the
    existing `GOOGLE_DESKTOP_OAUTH_CONFIG` override) and uses the config
    redirect host when starting loopback OAuth. A local user-only config file
    was installed on this Mac with `0600` permissions; it is not in git and
    must not be committed or printed because it contains the Desktop OAuth
    client secret.
  - After that macOS OAuth fix, Settings > Google login was re-tested on this
    Mac. Browser login returned to Daily, the account email was shown, and the
    sync status displayed completion instead of "Google 토큰 요청 실패".
  - Verification passed after the macOS OAuth fix:
    `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
    with 31 tests.
  - iPhone 17 simulator UX smoke resumed after interruption:
    - Home month view rendered correctly with Dynamic Island safe-area spacing,
      visible event chips, no text overlap, and disabled empty-input send
      button.
    - Typing into the bottom schedule input enabled the send button. Submitting
      text opened the confirmation bottom sheet with readable title/date/
      category/reminder copy and non-overlapping `취소`/`등록` actions.
    - Cancelling the sheet did not create a test event and returned to the
      calendar.
    - View-mode menu displayed `주`/`월`/`일` without clipping; week view
      switched successfully and showed stable day cards plus the bottom input
      area.
    - More menu displayed `빠른 보기`/`필터`/`검색`/`설정` without clipping.
      Search and Settings screens opened, and the account/sync section was
      readable with non-overlapping sync/logout/withdraw controls. Destructive
      account controls were not pressed.
    - No additional iPhone simulator UX defect was found that required a code
      change in this pass.
- User still needs to perform the actual iPhone Google login flow on the
  installed latest build and report whether it still stays on
  "계정 백업 확인 중".
- If iPhone still hangs, instrument the login path around:
  - `GoogleDriveAuthService.signIn()`
  - `authorizationHeaders(promptIfNecessary: true)`
  - `GoogleDriveSyncService.startListeningOnly()`
  - `syncPendingChangesNow(promptIfNecessary: true, restoreAfterBackup: true)`
- Confirm iOS/macOS do not duplicate Drive consent requests during sign-in.
- Confirm iOS/macOS do not run both listener startup restore and a separate full
  sync during connect.
- Confirm iOS/macOS keep user approval waits separate from short network/token
  waits.
- Verify same shared Flutter behavior on iOS/macOS where relevant:
  natural month swipe settling, stable month detail loading, compact settings
  layout, locked category affordance, and robust Google Drive authorization
  validation.
- Perform actual UX/UI demonstration testing on simulator/device where
  available and fix bugs, vulnerabilities, optimization needs, delays, and
  UX/UI issues found.
- 2026-07-02 App Review response work:
  - Apple rejected iOS `2.0.5(10)` on 2026-06-25 for Guideline 5.1.2(i)
    because App Privacy metadata indicated data used for tracking, and for
    Guideline 4.8 because Google login appeared to be a primary account login
    without an equivalent login option.
  - Code was updated to clarify that Daily can be fully used without an
    account and that Google is only an optional Google Drive AppData backup/
    sync connection:
    - Welcome copy now says all calendar features work without an account.
    - Initial Google action now says `Google Drive 백업 복원`.
    - Settings action now says `Google Drive 연결`; disconnect/delete wording
      no longer presents this as Daily account login/withdrawal.
  - `docs/STORE_SUBMISSION.md` now includes App Review reply drafts for both
    5.1.2(i) and 4.8 plus the exact App Privacy label corrections.
  - `docs/PRIVACY_POLICY.md` now says optional Google Drive connection rather
    than optional Google sign-in.
  - Verification after these changes passed:
    `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
    with 31 tests.
  - App Store Connect still must be updated manually:
    - App Privacy: collected data can remain Email Address, User ID, and Other
      User Content for app functionality, linked to identity when Drive sync is
      enabled, but `Used for Tracking` must be `No`.
    - Reply to App Review explaining Daily has no primary account requirement;
      local mode is full-featured, and Google authorization is only optional
      Google Drive AppData backup/sync.
- 2026-07-02 iOS/macOS App Review UX smoke/debug continuation:
  - Shared code still had user-facing error/status strings that said
    `Google 로그인` or `다시 로그인` inside the auth/sync services. These could
    appear after failed Drive authorization and undermine the App Review 4.8
    explanation.
  - Updated `GoogleDriveAuthService` and `GoogleDriveSyncService` messages to
    describe the flow as `Google Drive 연결`, `권한 승인`, or `다시 연결`.
  - Fixed a desktop OAuth error wording bug where macOS token request failures
    could incorrectly say `Windows Google 로그인...`; desktop OAuth errors now
    use a platform label (`macOS`, `Windows`, or `데스크톱`).
  - Added a focused sync test to ensure missing Google auth headers show
    `Google Drive 연결이 필요합니다.` and do not issue Drive requests.
  - Verification passed after this continuation:
    `./tool/flutter.sh analyze --no-pub`,
    `./tool/flutter.sh test --no-pub`, and
    `./tool/flutter.sh test --no-pub test/core/sync/google_drive_sync_service_test.dart`.
    The full suite now has 32 tests.
  - macOS debug app was rebuilt and launched through `./tool/run_macos.sh`.
    It was signed with the local Apple Development identity and opened one
    visible `Daily` window from `~/Applications/Daily.app`. Calendar month
    view and Settings entry rendered correctly. No duplicate Daily process was
    left by the launcher.
  - iOS Simulator `iPhone 17 Pro Max` on iOS 26.5 was booted and ran the app.
    The first-run screen showed the corrected copy:
    account-free full calendar use and optional `Google Drive 백업 복원`.
    Local start entered the calendar, the More menu showed Settings, and
    Settings opened with normal notification/calendar controls.
  - iOS notification permission appeared after local start. The agent asked for
    explicit confirmation before pressing `허용` because it changes notification
    permission state. The prompt was not accepted by the agent.
  - Automated iOS GUI scrolling is limited in this environment: Computer Use
    currently exposes click/state but no drag/scroll tool, and `simctl ui` has
    no touch scroll command. Lower Settings sections were therefore confirmed
    through shared Flutter code and widget tests rather than iOS GUI scrolling
    in this pass.
- 2026-07-02 Android/Windows parity and handoff:
  - The user clarified that only Android/Windows-related remote changes should
    be considered, not a full pull/merge. `git fetch origin` was run and
    `git diff --name-status HEAD..origin/main -- android windows` showed no
    remote Android/Windows platform file changes to import.
  - Android and Windows platform files did not need code changes. The actual
    parity fixes are in shared Flutter auth/sync code and Android/Windows
    release docs:
    - User-facing auth/sync failures now say `Google Drive 연결`, `권한 승인`,
      or `다시 연결` instead of presenting the flow as a Daily account login.
    - Windows Desktop OAuth token/configuration errors now use the correct
      platform label and describe Google Drive connection failures.
    - Android Play submission copy now states that local mode is fully usable
      without an account and Google Drive AppData sync is optional.
    - Android release checklist now tests local start, optional Google Drive
      restore, connection disconnect choices, and Drive backup deletion instead
      of old logout/member-withdrawal wording.
    - Google Drive setup and progress docs now describe Android/Windows as the
      same optional Drive AppData v2 sync model used by iPhone/macOS.
  - Verified by search that the Android/Windows target docs and shared app code
    no longer contain the old `Google 로그인`, `회원탈퇴`, `Google login`,
    `Google Sign-In`, or `membership withdrawal` wording, except code symbols
    such as `GoogleSignInAccount` in implementation files.
  - Windows still needs a real Windows machine test after this commit:
    - build with `.\tool\flutter.ps1 build windows --release --no-pub`
    - launch the release app
    - confirm local mode starts without an account
    - confirm Google Drive connection opens the desktop OAuth browser flow
    - confirm invalid/missing Desktop OAuth secret errors show Google Drive
      connection wording, not Google login wording
    - confirm connect, manual sync, disconnect choice, and Drive backup deletion
      match Android/iPhone/macOS behavior.
  - Android still needs real-device or emulator smoke after this commit:
    - clean install the release/AAB-equivalent build
    - confirm local mode starts without an account
    - confirm optional Google Drive connection and v2 AppData restore
    - confirm create/update/delete sync, notification permission, disconnect
      choices, and Drive backup deletion.

- 2026-07-04 Sign in with Apple implementation for App Review 4.8:
  - Added real Sign in with Apple support for Apple platforms through
    `sign_in_with_apple` 8.1.0.
  - New shared auth files:
    - `lib/core/auth/apple_account.dart`
    - `lib/core/auth/apple_sign_in_service.dart`
  - Apple login is exposed on iOS/macOS only. The welcome screen now shows
    `Apple로 계속` above local start and optional Google Drive restore.
  - Apple sign-in requests only email and full name scopes, stores the returned
    local Apple user identifier plus optional email/name, and preserves the
    stored email/name on later Apple sign-ins because Apple only returns them
    on first authorization.
  - Settings now has an Apple login section on iOS/macOS. Apple logout removes
    only the Apple local session and keeps local events/settings. Local reset
    clears Apple login state too.
  - iOS and macOS native entitlements now include
    `com.apple.developer.applesignin = Default`, and both Xcode projects mark
    the Sign in with Apple capability.
  - iOS App Store IPA was built as `2.0.5(14)` and copied to:
    `dist/transporter-upload/Daily-iOS-Transporter-2.0.5-build14.ipa`
  - IPA verification:
    - bundle id: `com.littlebit0.daily`
    - version: `2.0.5`
    - build: `14`
    - signed entitlement includes
      `com.apple.developer.applesignin = Default`
    - SHA-256:
      `eda05bbb359449569e888524a539c387aa142c6f30da1896b506cecaec9cd7ba`
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub` (33 tests)
    - `./tool/flutter.sh build ios --simulator --debug --no-pub`
    - iOS Simulator `Daily Store 6.5` launched the fresh app and the first
      screen showed the new `Apple로 계속` button.
    - `./tool/flutter.sh build ipa --release --no-pub --build-name=2.0.5
      --build-number=14`
  - macOS Apple-login signing follow-up on 2026-07-04:
    - The first local macOS app installed to `/Users/kimhwi/Applications`
      was ad-hoc signed, so Apple login failed immediately with
      AuthenticationServices authorization error 1000 / AuthKit -7026.
    - The macOS Runner target was corrected to use Daily's Apple developer
      team `A6Y73X2ZLS` instead of the stale `739BC896PZ` team.
    - `xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration`
      registered this Mac and generated
      `Mac Team Provisioning Profile: com.littlebit0.daily.macos`.
    - A signed Debug build succeeded and was installed to
      `/Users/kimhwi/Applications/Daily.app`.
    - Installed macOS app verification:
      - bundle id: `com.littlebit0.daily.macos`
      - TeamIdentifier: `A6Y73X2ZLS`
      - signed entitlement includes
        `com.apple.developer.applesignin = Default`
    - The app process launched successfully from the signed install. The actual
      Apple ID approval step should be completed by the user; do not enter or
      submit Apple ID credentials on the user's behalf.

- 2026-07-04 macOS local data reset follow-up:
  - User reported an error when pressing Settings > `로컬 데이터 초기화`.
  - Screenshot inspection showed Settings stuck in a busy state with
    `Google Drive 연결` spinning and `로컬 데이터 초기화` disabled, not a visible
    error dialog.
  - macOS logs showed repeated native notification authorization failures from
    `com.littlebit0.daily.macos`.
  - Root cause found in shared Settings code: local reset awaited event reminder
    and morning briefing notification cancellation before clearing local data.
    On macOS, that cancellation can initialize native notifications and request
    authorization, so notification permission/signing state could block or fail
    local data reset.
  - Fix: local reset now attempts notification cleanup with a short bounded
    timeout and does not let notification cleanup failures stop local event,
    settings, Apple-session, or Google-account reset work.
  - Added widget coverage that intentionally makes notification cleanup throw
    during local reset and verifies the app still clears data and returns to the
    welcome screen.
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub test/widget_test.dart`
    - local unsigned macOS debug build via `xcodebuild` with signing disabled
    - rebuilt app installed to `/Users/kimhwi/Applications/Daily.app` and
      launched successfully
  - Destructive GUI reset was not pressed during this pass because it would
    delete the user's current local Daily data.

- 2026-07-04 Google Drive auth-cancel UX follow-up:
  - User requested no new upload/distribution artifacts until explicitly asked;
    only bug fixing, feature testing, and debug/simulator runs should continue.
  - Fixed a Google Drive login cancellation bug where starting Google Drive
    connection from an unlinked state and then closing/leaving the login window
    could leave the connect/restore button stuck in a loading-disabled state.
  - Desktop OAuth now has a real pending sign-in cancellation signal. When the
    app resumes while a desktop browser OAuth request is pending, the local
    callback server wait is canceled and the UI returns to an actionable state.
  - Welcome and Settings Google Drive flows now track stale connection attempts
    so a canceled or late-completing auth Future cannot re-disable the button or
    accidentally continue restore/sync work.
  - iOS native Google Sign-In cancellation remains handled by the plugin's
    canceled/error return path; the desktop resume-cancel hook is only used for
    desktop OAuth.
  - Added widget coverage for both first-run `Google Drive 백업 복원` and Settings
    `Google Drive 연결` buttons to verify they re-enable after the auth window is
    abandoned.
  - Verification passed:
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub test/widget_test.dart`
    - `./tool/flutter.sh test --no-pub`
    - `./tool/flutter.sh build ios --simulator --debug --no-pub`
  - Installed and launched the debug simulator build on `Daily Store 6.5`
    (`2D0F9792-793F-4F86-95A9-02A7462060FA`). This was not an upload artifact.

- 2026-07-04 physical iPhone install follow-up:
  - User asked to install Daily on the physical iPhone, with no new upload
    artifacts.
  - The connected device is `김휘의 iPhone`, UDID
    `00008150-00012D5421F3401C`, CoreDevice id
    `415EDAF7-A303-50FD-8344-351D7BF59153`, running iOS `26.5.1`.
  - Fixed iOS project signing for physical-device builds by setting
    `DEVELOPMENT_TEAM = A6Y73X2ZLS` on the Runner Debug/Profile/Release build
    configurations in `ios/Runner.xcodeproj/project.pbxproj`.
  - `./tool/flutter.sh build ios --debug --no-pub` succeeded, and the resulting
    `build/ios/iphoneos/Runner.app` has the expected team id and
    `com.apple.developer.applesignin = Default` entitlement.
  - `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration
    Debug -destination id=00008150-00012D5421F3401C
    -allowProvisioningUpdates build` also succeeded.
  - Installation is currently blocked before app transfer: the iPhone is only
    visible over `localNetwork`/Wi-Fi and CoreDevice does not expose the
    `Install Application` capability (`com.apple.coredevice.feature.installapp`).
    `devicectl device install app` and `flutter install` both fail for that
    reason.
  - `xcrun xcdevice wait --usb --timeout=5 00008150-00012D5421F3401C` did not
    find the device over USB. Next retry should use a USB cable, keep the iPhone
    unlocked, trust the Mac if prompted, then rerun installation.
  - Follow-up wireless check: `xcrun xcdevice enable --timeout=15
    00008150-00012D5421F3401C` completed, but CoreDevice still did not expose
    `Install Application`. The current Wi-Fi/localNetwork connection can launch,
    uninstall, view screen, and transfer files, but cannot install app bundles.
  - Practical wireless install alternatives are TestFlight over-the-air or
    Ad Hoc/release-testing OTA distribution with a signed IPA and manifest.
    Both require a distributable build artifact, so do not use them until the
    user explicitly permits a new upload/distribution build.
  - After the user connected USB, `xcrun xcdevice wait --usb --timeout=20
    00008150-00012D5421F3401C` succeeded and CoreDevice reported
    `transportType: wired`, but `Install Application` was still absent.
  - Root cause now appears to be incomplete Xcode first-run platform setup:
    Xcode 26.6 is showing the "Select the components you want to get started
    with" dialog. iOS 26.5 platform support (`8.52 GB`) is selected but not
    installed. watchOS/tvOS/visionOS were deselected in the dialog so only iOS
    remains selected.
  - Do not click `Download & Install` through GUI without explicit user
    confirmation because it downloads/installs Xcode platform support.
  - Follow-up correction: Xcode first-run/platform support was ultimately not
    the blocker. Xcode 26.6 showed iOS 26.5 SDK installed, and
    `xcodebuild -checkFirstLaunchStatus` was clean. The real blocker was a
    stale CoreDevice/DDI pairing state after USB/wireless switching.
  - Tried `xcodebuild test`; this first exposed missing `DEVELOPMENT_TEAM` on
    `RunnerTests`, so `A6Y73X2ZLS` was added to RunnerTests Debug/Profile/Release
    build configurations. The next test attempt still failed at install with
    `Install Application not available`, confirming it was not an app build
    error.
  - Rebooted the physical iPhone with `devicectl device reboot`, waited for USB,
    then ran `devicectl manage pair --device 00008150-00012D5421F3401C`.
    Device moved from `unavailable` to `connected (no DDI)`.
  - Running `devicectl device info ddiServices` then re-enabled DDI; capability
    list finally included `Install Application`.
  - Installed `build/ios/iphoneos/Runner.app` successfully:
    bundle id `com.littlebit0.daily`, version `2.0.5`, bundle version `2.0.5`.
    Then launched the app on `김휘의 iPhone` via `devicectl device process launch`.

- 2026-07-04 version scheme update and iPhone reinstall:
  - User defined the new public version scheme: an App Store-style
    `2.0.5(14)` should be represented in-project as `2.5.14`; similarly
    `3.0.2(20)` becomes `3.2.20`.
  - Going forward, do not use a separate user-facing build-number suffix.
    Use the mapped version string itself as both the display version and bundle
    version where the platform allows it.
  - Updated common Flutter version to `2.5.14` in `pubspec.yaml`.
  - Updated Windows MSIX metadata to `2.5.14.0` and output name
    `daily-windows-2.5.14`.
  - Updated stale iOS/macOS RunnerTests Xcode `MARKETING_VERSION` and
    `CURRENT_PROJECT_VERSION` values to `2.5.14`.
  - Rebuilt iOS debug app successfully and verified
    `CFBundleShortVersionString = 2.5.14` and `CFBundleVersion = 2.5.14`.
  - Uninstalled the previous physical iPhone Daily install (`2.0.5/2.0.5`) and
    installed the new build. Device app listing confirms Daily
    `Version 2.5.14`, `Bundle Version 2.5.14`.
  - Launch attempt after install was denied because the physical iPhone was
    locked, not because of an app build failure.
  - Follow-up crash diagnosis: the installed iPhone app kept quitting because
    it was a Flutter `--debug` build installed directly with `devicectl`.
    Console log showed:
    `Cannot create a FlutterEngine instance in debug mode without Flutter
    tooling or Xcode.`
  - Fix was not app-code related: rebuilt iOS as a standalone launchable app
    with `./tool/flutter.sh build ios --release --no-pub`, then uninstalled the
    debug install and reinstalled `build/ios/iphoneos/Runner.app`.
  - Verified release install on the physical iPhone:
    - App listing: Daily `Version 2.5.14`, `Bundle Version 2.5.14`
    - Normal `devicectl device process launch` succeeded
    - Process list showed one live Runner process from the new install path
  - For future physical iPhone installs intended for normal Home Screen use,
    do not install `--debug` builds directly. Use release/profile or launch
    debug builds only through `flutter run`/Xcode.

- 2026-07-04 iOS 2.5.14 Transporter IPA and login screenshot:
  - User confirmed the iPhone build is now normal and requested Transporter IPA
    plus a login-screen screenshot using the App Store allowed size.
  - Built App Store IPA with `./tool/flutter.sh build ipa --release --no-pub`.
    Flutter validation reported:
    - Version Number: `2.5.14`
    - Build Number: `2.5.14`
    - Bundle Identifier: `com.littlebit0.daily`
  - Copied IPA to
    `dist/transporter-upload/Daily-iOS-Transporter-2.5.14.ipa`.
  - Verified IPA `Info.plist`:
    - `CFBundleShortVersionString = 2.5.14`
    - `CFBundleVersion = 2.5.14`
  - Rebuilt and installed simulator app on `Daily Store 6.5`
    (`2D0F9792-793F-4F86-95A9-02A7462060FA`) after uninstalling existing
    simulator app data.
  - Captured login/start screen at the App Store-accepted size:
    `dist/app-store-screenshots/ios-login/daily-login-1242x2688.png`
    (`1242 x 2688`).

- 2026-07-04 macOS month-grid drag range creation fix:
  - User reported that continuous/multi-day event creation by dragging on
    macOS did not work.
  - Root cause found in `CalendarMonthGrid`: desktop pointer drag selection and
    touch long-press selection shared the same `_rangeStart`/`_rangeEnd` state,
    so Flutter's `GestureDetector` long-press cancellation could clear the
    desktop drag range before the pointer-up event finished it.
  - Fix:
    - Desktop primary-button drag and touch long-press range selection now have
      separate active-state guards.
    - Long-press cancel no longer clears an active desktop drag range.
    - Pointer move no longer treats a missing primary-button bit as an immediate
      finish, because desktop test/engine move events can vary there while the
      pointer-up event is the reliable completion signal.
    - The month `PageView` no longer accepts desktop pointer drags, so dragging
      across the month grid is reserved for range creation instead of also
      trying to page months.
  - Added widget coverage in `test/features/calendar/calendar_month_grid_test.dart`
    for primary mouse drag from May 4 to May 8 creating a normalized date range.
  - Verification passed:
    - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
    - `./tool/flutter.sh analyze --no-pub`
    - `./tool/flutter.sh test --no-pub` (37 tests)
  - Local macOS test install:
    - Closed/replaced the existing `/Users/kimhwi/Applications/Daily.app`
      bundle without deleting app data.
    - Installed an Xcode development-signed Debug build from the current code.
    - Installed app verification: version `2.5.14`, bundle version `2.5.14`,
      bundle id `com.littlebit0.daily.macos`, TeamIdentifier `A6Y73X2ZLS`,
      Sign in with Apple entitlement present.
    - Launched `/Users/kimhwi/Applications/Daily.app`; process was running as
      `/Users/kimhwi/Applications/Daily.app/Contents/MacOS/Daily`.
  - GitHub issue #6 UI follow-up:
    - User approved applying the fix to both macOS and iOS.
    - The date-range selection UI now renders as a continuous row-level
      highlight instead of per-day separated selected cells.
    - The highlight is implemented in shared Flutter code, so macOS and iOS use
      the same behavior. It rounds only the true range start/end and uses flat
      edges when the selected range continues across week rows.
    - Added widget coverage that verifies a May 4-May 8 drag shows a single
      wide `selected-range-2026-5-4` highlight while still creating the correct
      normalized date range.
    - Verification passed:
      - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
      - `./tool/flutter.sh analyze --no-pub`
      - `./tool/flutter.sh test --no-pub` (37 tests)
      - `./tool/flutter.sh build ios --simulator --debug --no-pub`
      - Installed/launched the updated simulator app on `Daily Store 6.5`
        (`2D0F9792-793F-4F86-95A9-02A7462060FA`).
      - Rebuilt and installed the updated macOS app to
        `/Users/kimhwi/Applications/Daily.app`; verified version `2.5.14`,
        bundle version `2.5.14`, TeamIdentifier `A6Y73X2ZLS`, and Sign in with
        Apple entitlement, then launched it.
    - Follow-up after user verification:
      - User confirmed the range creation worked but reported that selected
        ranges over holidays still did not visibly change color.
      - Root cause: holiday day-cell backgrounds were opaque and covered the
        row-level selected-range highlight painted underneath them.
      - Fix: day cells inside an active range now keep their own selected/holiday
        backgrounds transparent so the continuous range highlight remains
        visible over holiday dates too.
      - Added widget coverage with a holiday on May 6 inside a May 4-May 8 drag
        range. The test verifies the wide selected-range highlight exists and
        the holiday cell background becomes transparent while the range is
        active.
      - Verification passed:
        - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
        - `./tool/flutter.sh analyze --no-pub`
        - `./tool/flutter.sh test --no-pub` (37 tests)
        - `./tool/flutter.sh build ios --simulator --debug --no-pub`
        - Installed/launched the updated simulator app on `Daily Store 6.5`
          (`2D0F9792-793F-4F86-95A9-02A7462060FA`).
        - Rebuilt and installed the updated macOS app to
          `/Users/kimhwi/Applications/Daily.app`; verified version `2.5.14`,
          bundle version `2.5.14`, TeamIdentifier `A6Y73X2ZLS`, Sign in with
          Apple entitlement, then launched it.
        - Built a signed iOS release app with
          `./tool/flutter.sh build ios --release --no-pub` and installed it on
          the connected physical iPhone `김휘의 iPhone`
          (`415EDAF7-A303-50FD-8344-351D7BF59153`).
        - Physical iPhone app listing confirmed Daily version `2.5.14`, bundle
          version `2.5.14`.
        - Launch from `devicectl` was denied only because the iPhone was locked;
          installation itself succeeded.
  - GitHub issue #4:
    - Issue title: `일정 시작 전 알림 건의`.
    - User approved implementing multiple start-before reminders and also asked
      that delivered push/local notifications must not disappear merely because
      Daily is opened.
    - Implemented multiple event reminders in shared Flutter code:
      - Added `CalendarEvent.reminderMinutesBeforeList` and
        `EventDraft.reminderMinutesBeforeList`.
      - Kept `reminderMinutesBefore` as a compatibility getter/input so old
        callers and old sync data still read as one selected reminder.
      - Added Drift schema v4 column `reminder_minutes_before_list` and migrated
        legacy `reminder_minutes_before` into `[value]`.
      - Google Drive v2 event JSON now writes `reminderMinutesBeforeList` while
        still writing/reading legacy `reminderMinutesBefore`.
      - Event editor now shows multi-select reminder chips plus custom reminder
        input instead of a single reminder dropdown.
      - Notification scheduling now creates one stable notification id per
        event/reminder-minute pair so selected reminders do not overwrite each
        other.
      - Cancel/reschedule paths pass old+new reminder minutes to remove stale
        pending reminders, including custom minute values.
    - Delivered-notification retention:
      - macOS native notification bridge now has `cancelPending`.
      - iOS AppDelegate now registers the same `daily/native_notifications`
        channel for `cancelPending`.
      - Daily cancellation/reschedule flows use pending-only cancellation on
        iOS/macOS, so already delivered notifications in Notification Center are
        left for the user to clear manually.
      - Android/Windows continue to use the plugin cancellation fallback because
        the current plugin API does not expose a pending-only cancellation path.
    - Verification passed:
      - `./tool/flutter.sh analyze --no-pub`
      - `./tool/flutter.sh test --no-pub test/features/events/event_editor_dialog_test.dart test/features/events/reminder_minutes_test.dart test/core/notifications/reminder_delivery_plan_test.dart test/features/chat/rule_based_schedule_parser_test.dart`
      - `./tool/flutter.sh test --no-pub` (41 tests)
      - `./tool/flutter.sh build ios --debug --simulator --no-pub`
      - `GOOGLE_DESKTOP_CLIENT_SECRET=... ./tool/flutter.sh build macos --debug --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...`
    - Needs manual UX smoke verification on macOS and iOS after install:
      - Create/edit an event with multiple reminders selected.
      - Confirm pending reminders are scheduled.
      - Confirm a delivered Daily notification remains in Notification Center
        after opening Daily until the user dismisses it.

## Recommended Next Steps

1. Upload `dist/transporter-upload/Daily-iOS-Transporter-2.0.5-build14.ipa`
   with Transporter and select build `2.0.5(14)` in App Store Connect.
2. In App Review Notes for build 14, state that Sign in with Apple was added:
   users can continue with Apple, use local-only mode, or optionally connect
   Google Drive AppData for backup/sync.
3. For macOS Apple-login verification, use the signed install at
   `/Users/kimhwi/Applications/Daily.app`. Do not replace it with an ad-hoc
   `CODE_SIGNING_ALLOWED=NO` build when testing Apple login.
4. Run `./tool/flutter.sh analyze --no-pub` and `./tool/flutter.sh test --no-pub`
   after any shared-code changes.
5. If releasing a shared sync-affecting update, publish Windows/Android and
   Mac/iPhone artifacts together.

## Batch Verification Checklist

- GitHub issue #4 multiple reminders:
  - On macOS and iOS, create a normal timed event with multiple reminders
    selected, including at least one custom minute value.
  - Reopen/edit the event and confirm all selected reminder chips are preserved.
  - Confirm the event syncs between macOS and iOS with the same reminder list.
  - Wait for at least two reminder times and confirm separate OS Notification
    Center alerts are delivered.
  - Open Daily after a notification has arrived and confirm the delivered
    notification stays in Notification Center until the user dismisses it.
  - Change the event reminder list and confirm removed reminders no longer fire.
  - Delete the event and confirm future pending reminders for that event stop
    firing.
- GitHub issue #5 search/calendar UX:
  - Status: implementation is in place, but user explicitly asked to defer
    hands-on UX testing until all current issue fixes are complete.
  - On macOS and iOS, tap the search icon and confirm the search field opens
    inline above the calendar instead of navigating to a separate page.
  - Confirm the calendar is pushed down with an animation while the search panel
    is open.
  - Type a query and confirm full-calendar search results appear below the
    inline search field; selecting a result should move the calendar to that
    event's date and close the search panel.
  - Confirm the filter sheet still controls the current-view search/filter
    behavior separately from the inline full search.
  - On iOS, confirm month previous/next buttons are not shown and month movement
    is done by swiping the calendar.
  - On iOS, confirm search, filter, and settings buttons are visible directly in
    the header instead of hidden behind a more menu.
  - On macOS and iOS, confirm the persistent bottom chat input is gone.
  - On macOS and iOS, confirm the bottom bar has `빠른 보기`, `주/월/일`, and
    `LLM` controls.
  - Press `LLM` and confirm the existing LLM schedule input opens in a bottom
    sheet and can still create an event.
  - On macOS and iOS, confirm week and day event lists scroll when they contain
    more events than fit.
  - On macOS month view, confirm two-finger/trackpad or horizontal mouse wheel
    scrolling moves between months.
- GitHub issue #8 version display:
  - Status: implementation is in place, but hands-on settings UI verification
    is deferred until the current issue batch is ready for one test pass.
  - Open Settings on macOS and iOS and confirm an `앱 정보` section appears near
    the bottom.
  - Confirm the `Daily 버전` tile displays the app version as `2.5.14` or the
    current package version without a `+build` suffix.
  - Confirm the Settings page still opens normally if package metadata loading
    is slow or unavailable.
- GitHub issue #9 category editing:
  - Status: implementation is in place, but hands-on settings/category UX
    verification is deferred until the current issue batch is ready for one test
    pass.
  - Open Settings on macOS and iOS and confirm user-editable categories show an
    edit button next to the delete button.
  - Edit a custom category name and color, save it, and confirm the category row
    updates without creating a duplicate category.
  - Assign an event to that category before editing, then confirm the event still
    remains in the same category after the category label/color change.
  - Confirm the default/basic category can be edited if present, while the locked
    holiday category remains non-editable and non-deletable.
  - Confirm category changes are saved after closing and reopening Settings.
- GitHub issue #10 Google Drive session restore:
  - Status: implementation is in place, but hands-on iOS/macOS verification is
    deferred until the current issue batch is ready for one test pass.
  - On iOS, connect Google Drive, fully terminate Daily, reopen it, and confirm
    Settings still shows the connected Google account instead of local mode.
  - On iOS, after the same restart, create or edit an event and confirm Google
    Drive sync continues without reconnecting.
  - On macOS, repeat the restart/open Settings flow and confirm the connected
    Google account is restored in the UI when a saved desktop OAuth session
    exists.
  - Confirm Daily does not open the Google login/permission window during app
    start or Settings open; only the explicit connect/sync buttons may prompt.
- GitHub issue #11 iOS month calendar density:
  - Status: implementation is in place. Pro Max simulator GUI confirmed that
    the filter sheet no longer crashes when pressing `완료`; final 13 mini/17
    GUI re-check was blocked by Codex usage-limit rejection on `simctl launch`.
  - Compact month-grid event density now targets standard-mode visible event
    counts by screen width: iPhone 13 mini-class width shows 4 events per busy
    day when height allows, iPhone 17-class width shows 5, and Pro Max-class
    width shows 6.
  - If the actual row height is too small, the grid reduces visible lanes before
    overlap and keeps the `+N` overflow indicator.
  - The `+N` overflow indicator now reserves its own line below visible event
    chips instead of being anchored to the bottom of the day cell, preventing
    overlap on compact iPhone widths.
  - The bottom calendar bar now sizes its quick-view icon, view segmented
    control, and LLM icon from the available bar width so the left/right icon
    controls and center tabs scale consistently by device width.
  - The filter sheet, app-lock PIN dialog, number dialog, and category
    add/edit dialog no longer dispose `TextEditingController` instances from
    the outer async function before the input widget has left the tree. Category
    and PIN/number dialogs now own their controllers in stateful dialog widgets.
  - macOS uses the same width-based target curve, so wide windows keep
    proportionally higher event capacity without a separate platform fork.
  - Verified:
    - `./tool/flutter.sh analyze --no-pub` passed.
    - `./tool/flutter.sh test --no-pub` passed.
    - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart` passed after bottom bar proportional sizing.
    - iOS simulator debug build succeeded with `./tool/flutter.sh build ios --simulator --debug --no-pub`.
    - Pro Max simulator GUI confirmed filter `완료` closes without the previous Flutter red screen.
  - Manual verification needed:
    - On iOS and macOS Settings, open category add and edit dialogs, save/cancel
      them, and confirm no Flutter red screen appears.
    - On iOS and macOS Settings, enable app password/PIN and confirm save/cancel
      does not trigger the same red screen.
    - iPhone 13 mini-equivalent simulator: create 5+ events on one day and
      confirm 4 are visible if the layout height allows it, otherwise at least
      3 are visible without overlap.
    - iPhone 17-equivalent simulator: confirm 5 events are visible on one busy
      day with overflow for additional events.
    - iPhone Pro Max-equivalent simulator: confirm 6 events are visible if the
      layout allows it, otherwise 5 are visible without overlap.
    - On macOS, later resize the month view across narrow and wide widths and
      confirm visible event capacity scales smoothly with no text overlap.

## 2026-07-06 Follow-up Fixes

- Category edit propagation:
  - When a category label/color is edited in Settings, existing events using
    that category are now resaved through `EventCommandService` with the updated
    category and color value.
  - This should make calendar chips update immediately after category edit
    instead of waiting until each event is manually edited and saved.
  - Because the command service save path is used, affected events are marked
    pending for sync and event notifications are rescheduled normally.
- User-created holidays:
  - The event editor now allows selecting the `공휴일` category.
  - Events created or edited with the holiday category set `holiday: true` while
    remaining user-editable (`readOnly/systemEvent` are not set by this path).
  - Stored events whose category is `holiday` are mapped back as holiday events
    so they render with holiday styling in the calendar.
- Morning briefing notifications:
  - The previous fixed body `오늘 일정을 확인할 시간입니다.` was replaced with a
    schedule summary body.
  - Daily now schedules the next 14 morning briefing notifications separately,
    each with that date's event summary. If there are more than four events, the
    body ends with `외 N개 더 있습니다.`
  - Event create/update/delete reschedules the morning briefing when it is
    enabled so changed schedules refresh the notification body.
- Bottom calendar bar:
  - The center `주/월/일` segmented control now uses a larger width ratio and
    the side icon buttons are slightly smaller, reducing the empty-space feeling
    on iPhone and wider layouts.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub` passed.
- Manual verification still useful:
  - Edit a custom category color and confirm existing calendar chips repaint
    immediately.
  - Add a personal holiday event and confirm it appears as a holiday-colored,
    editable event.
  - Create more than four events on a future morning briefing date and confirm
    the notification body summarizes visible events plus `외 N개 더 있습니다.`
  - Check iPhone 13 mini / iPhone 17 / Pro Max bottom bar visual balance.

## 2026-07-07 UI and Category Follow-up

- Bottom calendar bar:
  - Replaced the separated icon/segmented controls with one integrated 5-item
    capsule: quick view, week, month, day, LLM.
  - The bar background now extends through the iOS safe-area bottom so the area
    below the controls no longer looks empty.
  - Follow-up: removed the gray capsule background because it looked detached
    from the white toolbar. The bar now uses a white native-toolbar treatment
    with only a soft selected state per item.
- Category edit propagation:
  - Reworked category usage updates to use a repository-level batch update
    before notification/sync follow-up work.
  - This should prevent visible one-by-one color changes and make the calendar
    show the completed color update when returning from Settings.
  - Custom category edits now normalize to the new label-based custom id so
    edited categories do not intermittently map back to the old color after
    reload/sync.
  - Hidden category filter ids are migrated when a category id changes.
- Month picker:
  - Month buttons now use one-line `FittedBox` labels so `1월`, `11월`, and
    `12월` do not wrap as separate number/text lines.
  - Follow-up: restored normal month label font size and widened the month
    picker dialog/content instead of scaling down `10월`/`11월`/`12월`.
- Time format:
  - Added a Settings option for 12h/24h time picker display.
  - Time picker dialogs in Settings now force the selected 12h/24h mode.
  - The setting is persisted locally and included in Drive settings sync.
	- Verification:
	  - `./tool/flutter.sh analyze --no-pub` passed.
	  - `./tool/flutter.sh test --no-pub` passed.
	  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed.
	  - Installed and launched on iPhone 17 simulator
	    `BF524643-403E-4212-ACB7-621E11279532`.

## 2026-07-07 Bottom Bar and Period Swipe Follow-up

- Bottom calendar bar:
  - The active `주/월/일` item background now fills the whole item cell from edge
    to edge inside the integrated bottom bar instead of leaving side gaps.
  - The bottom bar content was moved lower by letting the page body extend to
    the screen bottom and letting the bar own its bottom safe area.
  - The bottom bar content width was reduced slightly by increasing horizontal
    inset from 10 to 18.
  - Follow-up: removed the separate bottom padding/margin and increased the bar
    height instead, so the selected item background color extends through the
    lower bar area instead of leaving a blank bottom gap.
- Week/day navigation:
  - Weekly and daily calendar views now use PageView-based horizontal paging,
    matching the monthly calendar swipe animation style.
  - Swipe left moves to the next week/day and swipe right moves to the previous
    week/day with the same page physics used by monthly navigation.
  - The same visible-range update path is used for header navigation and body
    swipes so selected date and visible month stay in sync.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart` passed.
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed.
  - Installed and launched on iPhone 17 simulator
    `BF524643-403E-4212-ACB7-621E11279532`.
  - Screenshot check confirmed the bottom bar reaches the bottom edge without
    the previous visible bottom gap.
- Manual verification still useful:
  - On iPhone 17 simulator, check that the bottom bar is lower, slightly
    narrower, and that the active color reaches the full selected item bounds.
  - Switch to weekly and daily modes, then swipe left/right to confirm period
    navigation feels correct.

## 2026-07-07 Apple Login Drives Google Sync

- Apple login flow:
  - Starting with Apple now first attempts silent Google Drive session restore
    via `restorePreviousSignIn()`.
  - If a Google Drive account was already connected/restorable on the device,
    Daily starts Drive sync automatically without showing the Google sign-in
    account picker.
  - If no restorable Google Drive session exists, Apple login now continues into
    the interactive Google login/Drive permission flow automatically after a
    short sequencing delay. This preserves the requested first-login linkage
    while reducing iOS back-to-back OAuth URL callback collisions.
  - Onboarding is completed only after Apple sign-in and Google Drive connection
    both succeed, preventing an Apple-only state with no Drive sync.
  - If the Google Drive permission flow is cancelled after Apple sign-in, the
    user remains on the welcome screen with a message explaining that Google
    Drive connection is required to continue with Apple.
- Settings Apple connection:
  - Connecting Apple from Settings now first attempts silent Google Drive restore
    and opens the Google login/Drive connection flow automatically if there is
    no restorable Google session.
  - Settings text no longer says Google Drive sync is a separate Apple-login
    choice; it explains that Apple login uses Google Drive for backup/sync.
- Account UX:
  - The welcome screen no longer exposes a first-login `Google Drive backup
    restore` action. It now offers `Google로 계속`, which uses the same
    login-and-Drive-sync flow as Apple.
  - `연결 해제` was renamed to `로그아웃`; logout now syncs once, signs out
    Apple/Google local session state, and returns directly to the welcome screen.
  - `Drive 백업 삭제` was renamed to `회원탈퇴`; membership withdrawal deletes
    the Drive AppData backup when available, clears local data/settings, signs
    out Apple/Google, and returns to the welcome screen.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` passed.
  - Added regression coverage for Apple first login automatically continuing
    into Google login when no restorable Google session exists.

## 2026-07-07 iOS Google Auth Crash Follow-up

- Crash diagnosis:
  - The post-Apple Google link crash was a native iOS Google Sign-In/AppAuth URL
    callback abort (`OIDAuthorizationSession resumeExternalUserAgentFlowWithURL`),
    not a catchable Dart exception.
- iOS auth change:
  - User clarified the desired Google auth UI: it should feel like an in-app
    popup/sheet rising over Daily, not a full jump to the Safari app.
  - iOS Google Drive auth now uses a custom `ASWebAuthenticationSession` method
    channel (`daily/google_oauth`) instead of `google_sign_in_ios`.
  - iOS OAuth uses the app's reversed Google client id URL scheme and PKCE
    redirect URI `com.googleusercontent.apps...:/oauth2redirect/google`; it no
    longer uses localhost redirects or launches Safari via `open`.
  - The iOS custom auth session exchanges the returned authorization code in
    Dart through the existing Google token/userinfo path and stores the refresh
    token in the existing secure storage-backed Drive session keys.
  - Fixed a follow-up blocker where iOS was still treated like desktop browser
    OAuth for lifecycle cancellation. `canCancelPendingSignInOnResume` is now
    false on iOS so the app returning from the authentication sheet no longer
    cancels the in-progress Google Drive connection.
  - Added the iOS OAuth client id from `ios/Runner/GoogleService-Info.plist` as
    the default `GOOGLE_IOS_CLIENT_ID`, so Google/Apple-to-Google connection
    does not require an extra build define to open the auth sheet.
  - Added serialization around mobile Google sign-in so Apple-login-to-Google
    linking cannot start overlapping interactive Google auth requests.
  - `SceneDelegate` still swallows Google callback URLs so the registered
    `google_sign_in_ios` plugin cannot receive duplicate callbacks and crash
    with AppAuth `resumeExternalUserAgentFlowWithURL`.
- Settings separation:
  - Settings now displays `Google 계정` and `Google Drive 동기화` as separate
    rows so the signed-in Google account and Drive sync status are not conflated.
- Verification:
  - `./tool/flutter.sh analyze --no-pub` passed.
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` passed.
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` passed after the
    `ASWebAuthenticationSession` auth path was added.
  - Installed and launched on iPhone 17 simulator with the new iOS auth path.

## 2026-07-08 iOS Google Auth Presentation Fix

- User-reported iPhone screenshot showed Google Drive linking failing with
  `com.apple.AuthenticationServices.WebAuthenticationSession error 3`.
- Root cause candidate fixed in native iOS code: `ASWebAuthenticationSession`
  could request its presentation anchor before a key window was discoverable,
  causing the session to fail immediately instead of showing the Google sheet.
- `DailyGoogleOAuthSession` now resolves a foreground visible window first and
  retains a clear fallback `UIWindow` tied to the active `UIWindowScene` when no
  key window is available. The fallback window is released when auth completes
  or fails.
- This keeps the Google auth flow as an in-app iOS authentication sheet over
  Daily rather than opening the standalone Safari app.

## 2026-07-08 Apple/Google Login State Fix

- User confirmed the iOS Google auth sheet opens normally, then reported account
  state issues after Apple login:
  - Apple login showed Google-button loading while entering the app.
  - Settings showed Google connected but Apple disconnected after relaunch.
  - After a normal logout, Apple login opened the Google popup again instead of
    silently reusing the previously linked Google Drive account.
- Behavior changed:
  - Apple onboarding now keeps the Apple button busy while it silently checks or
    connects Google Drive. The Google button shows a spinner only when the user
    explicitly chooses Google.
  - `AppleSignInService.refreshCurrentAccount()` no longer deletes the saved
    Daily Apple account marker when iOS reports a revoked/transient credential
    state. Apple account data is cleared only by explicit Daily logout or
    membership withdrawal.
  - Normal account logout no longer clears saved Google Drive auth tokens. It
    syncs pending changes, returns to the welcome screen, and preserves the
    saved Apple and Google Drive link markers so the next Apple/Google login can
    restore the paired account state automatically without prompting.
  - Membership withdrawal/local reset still clears local data, Apple account
    data, and Google Drive auth/session data when applicable.

## 2026-07-08 Reciprocal Apple/Google Link Persistence

- User requested the reciprocal path: if Apple was already linked, signing in
  through Google later should automatically keep Apple linked too.
- Normal `로그아웃` now preserves both saved Apple and Google Drive account link
  state and only marks onboarding incomplete to return to the welcome screen.
- `회원탈퇴` remains the destructive account-removal path and still clears Apple
  account data plus Google Drive auth/session data when applicable.
- Added widget coverage confirming Google logout returns to onboarding while
  preserving the saved Apple account marker for the next Google/Apple login.
- Follow-up UI cleanup: account settings now exposes a single unified
  `로그아웃` button for the whole account section. Apple and Google Drive rows keep
  their sign-in/sync actions, but no longer show separate logout buttons.

## 2026-07-08 Cross-Platform Parity Handoff

- macOS, Android, and Windows must be brought to the same account UX and sync
  policy as the latest iOS work before their next user-facing build:
  - Welcome screen should expose Apple where supported, local start, Google
    continue, and notification permission consistently with iOS wording.
  - Apple login, where supported, should first restore an existing Google Drive
    AppData session silently and open Google authorization only when no saved
    Drive session exists.
  - Google login should preserve an already linked Apple account marker, so
    either login path restores the paired account state.
  - Settings should show Google account and Google Drive sync as separate rows,
    but only one unified `로그아웃` button for the entire account section.
  - Normal `로그아웃` must sync pending changes and return to onboarding while
    preserving saved Apple/Google link state for future automatic restore.
  - `회원탈퇴` remains the only destructive account removal path and must clear
    local data/settings plus Apple/Google auth/session state and Drive backup
    where applicable.
  - iOS Google auth now uses an in-app `ASWebAuthenticationSession` sheet with a
    valid presentation anchor and retry handling. macOS should keep equivalent
    user-visible behavior with its supported auth mechanism; Android/Windows
    should keep the same account-state semantics even if their native auth UI is
    different.
- Required verification for macOS/Android/Windows agents:
  - Fresh install: Apple/Google/local onboarding paths.
  - Apple then Google link, app restart, settings account rows.
  - Logout then Apple login: Google Drive restores without a prompt when saved.
  - Logout then Google login: Apple marker remains linked when previously saved.
  - Membership withdrawal clears both account markers and Drive backup.
  - Manual sync and create/update/delete event sync still use v2 AppData files.

## 2026-07-08 Release 2.5.15 Preparation

- User approved recommended version `2.5.15`.
- Updated shared Flutter version and Windows MSIX metadata from `2.5.14` to
  `2.5.15`.
- Updated stale iOS/macOS Xcode test target marketing/build values to `2.5.15`.
- GitHub Release should upload only one IPA asset for this release, per user
  instruction.
- Prepare two local IPA copies after build:
  - Transporter/App Store Connect upload IPA.
  - Physical iPhone install/check IPA for user-side installation.
- App Store Connect notes to update:
  - Select the latest uploaded `2.5.15` iOS build.
  - Review notes should mention Apple and Google login are both available.
  - Google Drive access is only for Drive AppData Daily backup/sync.
  - Daily does not access normal Google Drive files.
  - Daily does not use IDFA, ads, data brokers, or cross-app/site tracking.

## 2026-07-08 Issue #15/#16 Release 2.5.16 Follow-up

- Issue #15 `애플 로그인 오류`:
  - Report: Apple login fails on a real iPhone when the IPA is installed through
    SideStore, showing only an unknown Apple login error.
  - Important limitation: SideStore/re-signed IPAs can lose the Sign in with
    Apple entitlement. Code cannot make native Apple Sign In succeed without the
    proper Apple entitlement in the installed app signature.
  - Fix: Daily now explains this case in the Apple unknown-auth error message
    and tells the user to use `Google로 계속` for SideStore builds or
    TestFlight/App Store builds for Apple login.
  - Regression test added for the SideStore/Google fallback message.
- Issue #16 `수정 분류 동기화 오류`:
  - Report: after moving to another iPhone, calendar event colors reflect an
    edited category, but the category color shown in Settings remains stale.
  - Fix: `GoogleDriveSyncService` now exposes a `settingsRevisionNotifier` and
    increments it when remote settings are restored. `_AppHome` listens for that
    signal and reloads `appSettingsProvider` from `SettingsRepository`, so
    Settings receives the restored category color immediately.
  - Regression test added to restore a remote category color and confirm both
    local settings storage and the revision notifier update.
- Version advanced to `2.5.16` instead of rewriting the already-pushed
  `v2.5.15` tag.

## 2026-07-08 Release 2.5.17 Retry / GitHub Actions Fix

- GitHub check after the `v2.5.16` push showed:
  - `v2.5.16` tag exists on GitHub.
  - GitHub Release object for `v2.5.16` was not created.
  - `Release Installers` failed because the Windows ZIP job failed at
    `flutter build windows --release --no-pub`.
  - Android and Apple jobs completed, but the final release publish job was
    skipped because Windows was in the `needs` list.
- Likely Windows failure cause: the project now uses user-facing versions like
  `2.5.16` without a `+build` suffix. Flutter leaves `FLUTTER_VERSION_BUILD`
  empty on Windows, but `Runner.rc` requires a numeric fourth version segment.
- Fix applied for Windows: `windows/runner/CMakeLists.txt` now defaults an empty
  `FLUTTER_VERSION_BUILD` to `FLUTTER_VERSION_PATCH`, preserving the user's
  no-`+` version convention while keeping Windows resource compilation valid.
- Release workflow changed from all-platform installers to an iOS-only IPA
  release workflow, matching the user's instruction that GitHub Release should
  upload only the IPA for this release.
- Version advanced to `2.5.17` for the retry instead of rewriting the failed
  `v2.5.16` tag.

## 2026-07-08 Release 2.5.17 Notes Rewrite

- User requested the GitHub Release note text be rewritten by referencing prior
  uploaded release notes.
- Added `docs/RELEASE_NOTES_2.5.17.md` using the older release-note structure:
  적용 범위, 변경 사항, 검증, 배포 파일, SHA-256, 남은 확인 사항.
- Updated `.github/workflows/release-installers.yml` to use
  `body_path: docs/RELEASE_NOTES_2.5.17.md` instead of the short inline release
  body.
- Important: the already-created GitHub Release `v2.5.17` still has the earlier
  short body unless it is edited through GitHub web/API or the workflow is
  manually dispatched with permissions that can update the existing release.

## 2026-07-12 App Review 2.6.0 Apple Login Fix / Maps Shortcut

- App Review rejected `2.5.17 (2.5.17)` on 2026-07-09 because `Apple로 계속`
  completed Apple authentication and then opened a Google login page, blocking
  review unless Google login was completed.
- Version advanced to `2.6.0` across shared Flutter metadata, iOS/macOS Xcode
  project values, Windows MSIX metadata, and README current-version notes.
- Fixed Apple login onboarding behavior:
  - `Apple로 계속` no longer opens Google sign-in interactively.
  - Apple login now completes local app entry even when no Google Drive session
    exists.
  - If a previous Google Drive session can be restored silently, Daily starts
    Google Drive sync without prompting.
  - If the silent restore fails or the stored session is missing, Daily stays in
    Apple/local mode and the user can connect Google Drive explicitly.
- Added Apple-to-Google link persistence in `SettingsRepository`:
  - `appleLinkedGoogleEmail`
  - `appleLinkedGoogleDisplayName`
  - normal logout preserves this link; `resetAll()`/회원탈퇴 clears it.
  - Explicit Google connection records the Google account when an Apple account
    is already saved.
- Settings Apple login flow was corrected the same way:
  - Apple login in Settings does not force-open Google login.
  - It only restores an existing Google session silently if available.
- Added one `지도 바로가기` action for events with a `location`:
  - Tapping it opens one bottom-sheet chooser.
  - Supported services: 카카오맵, 네이버지도, Apple 지도.
  - iOS `LSApplicationQueriesSchemes` now includes `kakaomap` and `nmap`.
  - Android manifest queries include `kakaomap` and `nmap`.
- Issue #16 follow-up:
  - Category add/edit/delete now performs a best-effort awaited `backupNow()`
    after local settings/event category updates so the remote settings file is
    less likely to lag behind event color updates on another device.
- Verification completed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
  - `./tool/flutter.sh build ipa --release --no-pub`
    - Archive validation: Version Number `2.6.0`, Build Number `2.6.0`,
      Bundle Identifier `com.littlebit0.daily`.
- Local 2.6.0 IPA copies:
  - `dist/release-2.6.0/daily-ios-2.6.0.ipa`
  - `dist/transporter-upload/Daily-iOS-Transporter-2.6.0.ipa`
  - `dist/device-install/Daily-iOS-Device-2.6.0.ipa`
  - SHA-256:
    `0b2e3fabbdfd7135c757fc697c6673c5466130927a4c0daff83697da65c5e82f`
- Still verify manually before App Store resubmission:
  - Fresh iPad/iPhone install: tap `Apple로 계속`; Google login must not appear.
  - Settings Apple login: Google login must not appear unless the user presses
    the explicit Google connect button.
  - With a previously connected Google account: Apple login should restore Drive
    sync silently when the Google session is still available.
  - Event with address/location: `지도 바로가기` bottom sheet should open and each
    map choice should launch or fall back correctly.
  - macOS/Windows/Android parity should be smoke-tested because shared Flutter
    account and event-detail code changed.

## 2026-07-15 macOS 2.6.0 Test Build

- The latest shared 2.6.0 Flutter code was built for macOS and installed at
  `~/Applications/Daily.app` for user testing.
- The previous Daily process was replaced and the new app was launched.
- Confirmed installed bundle version and build number are both `2.6.0`.
- Apple sign-in entitlement and macOS network entitlements remain present.
  The Apple/Google/local onboarding, saved Google Drive restoration, account
  settings, and location map chooser use shared Flutter code with iOS.
- User will perform interactive functional testing; do not continue UI actions
  unless specifically requested.

## 2026-07-15 Month Event Density Follow-up

- At the current macOS Daily window size (approximately `800 x 720`), month
  cells had enough vertical space for only one to three event flags even though
  the width-based density target allowed more.
- `CalendarMonthGrid` now renders five-week months in five rows rather than
  always reserving an empty sixth row. Six-week months remain six rows.
- This gives the current July desktop layout enough vertical space to preserve
  readable 13px event rows while showing four schedules. The `+N` overflow
  marker remains below the visible rows.
- Added a regression test for an `800 x 570` month-grid area, matching the
  current desktop calendar content height, which requires four visible events.
- Added a regression test confirming a five-week month does not render an
  empty sixth week.
- Verified with the latest installed macOS build: a day containing four
  schedules renders all four readable flags in the current window size.
- Verification passed:
  - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
  - `./tool/flutter.sh analyze --no-pub`

## 2026-07-15 Calendar Navigation Restoration

- Removed the iOS-style fixed bottom navigation bar from the shared calendar
  screen, including its LLM shortcut.
- Restored the previous header navigation pattern:
  - desktop-width screens show the `주 / 월 / 일` segmented view control in
    the header, together with range navigation and utility actions;
  - compact screens use the header's view-selection menu and more-actions
    menu, avoiding a bottom bar.
- The calendar body now receives the reclaimed bottom-bar height. The shared
  Flutter change applies to macOS and iOS.
- macOS visual check passed with the restored header controls visible.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/features/calendar/calendar_month_grid_test.dart`

## 2026-07-15 macOS Google Drive Connection Cancellation Fix

- Root cause of the reported macOS Google Drive connection failure: the
  onboarding and Settings lifecycle observers treated a browser focus change
  as an aborted desktop OAuth flow. Daily then cancelled its loopback OAuth
  listener before Google could return the authorization callback.
- Removed all lifecycle-driven OAuth cancellation. A Google Drive connection
  now remains pending while the user completes browser authentication, even
  when the app becomes inactive and resumes.
- Added an explicit `연결 취소` action during a pending desktop Google Drive
  connection. This is the only in-app path that cancels the loopback OAuth
  listener, so users can deliberately recover without guessing at lifecycle
  timing.
- The shared Flutter behavior applies to macOS and Windows desktop OAuth
  flows. iOS/Android retain their platform-native Google authorization flow.
- Tests now verify inactive-to-resumed lifecycle transitions do not cancel a
  pending connection and that the explicit cancellation control does.

## 2026-07-15 Android and Windows Account-Flow Parity

- The latest shared account, onboarding, settings, Google Drive sync, and
  calendar behavior is applied to Android and Windows through Flutter shared
  code. No separate platform UI implementation is needed for these changes.
- Android follows the iOS/mobile pattern:
  - Google authorization uses the platform-native mobile flow.
  - The UI shows `Google 연결 중` while authorization is pending and does not
    expose a desktop-loopback cancellation control.
- Windows follows the macOS/desktop pattern:
  - Google authorization opens the system browser and waits for the loopback
    OAuth callback without lifecycle-driven automatic cancellation.
  - While it is pending, the user can use the explicit `연결 취소` control.
  - The desktop OAuth configuration lookup supports
    `%APPDATA%\\Daily\\google_desktop_oauth.json`,
    `%LOCALAPPDATA%\\Daily\\google_desktop_oauth.json`, or the
    `GOOGLE_DESKTOP_OAUTH_CONFIG` override. The JSON may contain a client
    secret and must remain outside Git.
- Shared verification passed on macOS:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- Android debug build was attempted but this Mac has no Android SDK configured
  (`ANDROID_HOME` unavailable), so a Windows/Android environment must still
  perform the following smoke checks before release.

### Android Verification Checklist

- [ ] Install a clean debug or release APK after removing any older Daily app.
- [ ] Start in `로컬로 시작`; create, edit, delete, and restart to confirm local
  events and settings persist without a Google account.
- [ ] Choose `Google로 계속`; complete Android's native Google account and Drive
  permission flow. While it is open, Daily must show `Google 연결 중`, must not
  expose `연결 취소`, and must not crash or remain permanently disabled after
  user cancellation.
- [ ] Confirm the connected email appears in Settings and that the first
  Google Drive AppData backup/restore completes.
- [ ] On a second device signed into the same Google account, create an event
  on one device and confirm the other device receives the v2 event file after
  sync/resume. Also verify an edit and deletion propagate correctly.
- [ ] Sign out, restart, and verify the intended saved Google session behavior
  is restored without an unwanted account-selection page. Confirm local-only
  mode remains usable when no Google account is connected.
- [ ] Check monthly, weekly, and daily calendar navigation; category color
  changes; holiday event selection; event address map chooser; scheduled event
  notification; and morning briefing in Android system notifications.

### Windows Verification Checklist

- [ ] Install/run a clean Windows build and confirm `Google로 계속` opens the
  system browser, not an embedded or blank web view.
- [ ] Complete browser Google sign-in and Drive AppData approval. Switching to
  the browser and back must not show `Google Drive 연결이 취소되었습니다.` before
  the OAuth callback finishes.
- [ ] During the pending browser flow, confirm `연결 취소` is visible and works
  only when the user deliberately presses it. Cancelling must re-enable
  `Google로 계속` and must not leave a blocked connection state.
- [ ] Confirm the connected email, initial Drive AppData backup/restore, and
  app restart token restoration. If a local desktop OAuth config is needed,
  verify it is stored outside Git at the documented APPDATA/LOCALAPPDATA path.
- [ ] Verify cross-device event create, edit, delete, all-day event date, and
  category/settings synchronization against the same Google Drive AppData
  account used by iOS/macOS/Android.
- [ ] Check local-only start, logout, account deletion/local reset, monthly
  calendar scrolling, weekly/daily navigation, address map chooser, event
  notifications, and morning briefing in the Windows notification center.
- [ ] Build a release executable or MSIX and confirm its displayed version is
  `2.6.0` with no Flutter `+` suffix.

## 2026-07-15 Release 2.6.0 Published

- Commit `ee0c5dd` (`Release Daily 2.6.0`) and tag `v2.6.0` were pushed to
  `littlebit0/Daily`.
- GitHub Actions run `29362235598` completed successfully and created:
  - Release page: `https://github.com/littlebit0/Daily/releases/tag/v2.6.0`
  - `daily-ios-2.6.0-unsigned.ipa`
  - `daily-macos-2.6.0-unsigned.dmg`
- A locally development-signed macOS DMG and a locally exported iOS IPA also
  exist under `dist/release-2.6.0/`. They are ignored by Git and must be
  recreated for a later manual distribution if needed.
- The iOS App Store version has already completed App Review approval. The
  GitHub IPA is not an App Store installer and does not replace the approved
  App Store build.

## 2026-07-15 Windows CI Compiler Compatibility

- GitHub Actions Windows debug build in run `29362233895` failed while
  compiling `flutter_local_notifications_windows 3.0.0` with the hosted
  Windows Server 2025 / Visual Studio 2026 toolchain. Its deprecated
  `experimental/coroutine` use now fails with STL1011.
- Updated `flutter_local_notifications` from `21.0.0` to `22.0.1`, resolving
  to `flutter_local_notifications_windows 3.1.1` and matching platform
  interface packages. This replaces the outdated Windows implementation rather
  than suppressing the compiler error.
- Local shared verification passed after the upgrade:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`
- The next `Platform Builds` Windows debug run must be checked before making a
  new Windows-containing release.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart`

## Security Notes

- The user previously pasted Google OAuth client JSON that included a
  `client_secret`; do not commit that secret.
- Keep GitHub tokens, Apple signing identities, provisioning profiles, Android
  keystores, OAuth secrets, and private config files out of the repository.
- The current iPhone-first Drive sync target uses project number
  `234127810480` for iOS, Android, and Windows Desktop OAuth.

## 2026-07-17 2.5.17 Baseline Reset

- App source, platform configuration, release workflow, tests, and release
  documents were rolled back to the exact `v2.5.17` tracked tree on branch
  `Cottlebit/rollback-to-v2.5.17`.
- `AGENT_MEMORY.md` is intentionally preserved as the cross-agent handoff
  record and is not part of the product-source rollback.
- Reapply post-`2.5.17` work one item at a time. Explain and obtain user
  approval before any UI change.

## 2026-07-17 Daily Account Provider Linking

- Reapplied from the `v2.5.17` product baseline as the first approved item.
- Daily now stores one local `DailyAccount` identity with independently
  attached Apple and Google providers. A provider is attached only after its
  own sign-in succeeds; matching email addresses are never used to merge
  accounts.
- Apple sign-in no longer opens an interactive Google login page. Apple-only
  users enter Daily immediately.
- If the same stored Daily account already has a Google provider and its
  authorization can be restored silently on the device, Google Drive AppData
  sync resumes. A missing or expired Google session leaves Apple/local use
  available and does not show a Google login page.
- `Google로 계속` is now the explicit Google account sign-in path. It requests
  the existing Google Drive AppData scope during that authorization, then
  attaches the Google account to the current Daily account and starts sync.
- Legacy pre-Daily-account Apple/Google local state is migrated once on app
  start so existing local users retain their connected session behavior.
- Settings now distinguishes the Daily account, Apple login, Google login,
  and Google Drive sync status. This was an approved text/status-only UI
  adjustment; no calendar UI was changed.
- Verification passed on macOS:
  - `./tool/flutter.sh test --no-pub`
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh build ios --simulator --debug --no-pub`
- Remaining manual verification for iOS/macOS/Android/Windows:
  - Apple-only sign-in enters the calendar without any Google auth sheet.
  - On the same Daily account, explicitly sign in with Google, grant Drive
    AppData, restart, then sign in with Apple and confirm only silent Google
    restoration occurs.
  - With a missing/revoked Google session, Apple sign-in remains usable and
    Settings offers an explicit Google login action.
  - Confirm Google sign-in on each platform shows the native/system OAuth UI,
  obtains Drive AppData consent, and starts the v2 sync flow.

## 2026-07-17 Desktop Google OAuth Cancellation

- Reapplied as the second approved post-`2.5.17` item.
- Returning to Daily from the system browser no longer cancels a pending
  macOS/Windows Google OAuth flow. The loopback callback remains active until
  completion, timeout, or user cancellation.
- While a desktop OAuth flow is pending, the primary action reads
  `Google 연결 중` and Daily exposes an explicit `연결 취소` control.
- The manual cancellation control is intentionally unavailable for iOS native
  authorization because that platform owns cancellation in its system auth
  sheet.
- Verification passed on macOS:
  - `./tool/flutter.sh test --no-pub`
  - `./tool/flutter.sh analyze --no-pub`

## 2026-07-17 Provider Unlink and Daily Account Deletion

- Reapplied as the third approved post-`2.5.17` item.
- Settings now has independent `Apple 연동 해지` and `Google 연동 해지`
  controls when the respective provider is attached to the local Daily
  account.
- Google unlink asks whether to keep or delete the Google Drive AppData
  backup. Keeping the backup preserves only cloud data; local calendar data
  remains available in both choices. Backup deletion must succeed before the
  provider is unlinked.
- Apple unlink shows the matching stored-data decision, but its `저장 내용
  초기화` action is disabled until iCloud storage is implemented. Apple unlink
  currently removes only the Daily-to-Apple provider connection and preserves
  local calendar data.
- The prior membership action is now `Daily 계정 탈퇴`. It removes the local
  Daily account record, Apple/Google provider and merge metadata, local events
  and settings, local OAuth session state, and Google Drive AppData backup.
  Future iCloud-backed Daily data must be deleted in this same flow.
- Verification passed on macOS:
  - `./tool/flutter.sh test --no-pub`
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh build ios --simulator --debug --no-pub`
- Remaining manual verification:
  - On iOS/macOS, confirm the disabled Apple stored-data button is visible in
    the unlink dialog and Apple unlink preserves local events.
  - Confirm Google unlink both preserves and deletes Drive AppData according
    to the selected action.
  - Confirm Daily account deletion prompts for Google authorization when the
    stored Google session has expired, then removes cloud and local data.

## 2026-07-17 Category Settings Backup Retry

- Reapplied as the fourth approved post-`2.5.17` item without UI changes.
- Adding, editing, or deleting an event category now triggers a second
  best-effort settings backup request after the category operation. For edits,
  the retry is deliberately queued after existing events have been updated to
  the new category/color.
- The existing first settings backup remains in place; GoogleDriveSyncService
  serializes these requests so the retry follows the first request.
- Verification:
  - `flutter analyze --no-pub` passed using an isolated writable Flutter home.
  - Full Flutter tests could not be rerun in the current restricted environment:
    the SQLite native-asset hook attempted to download its macOS library from
  GitHub, but network access is unavailable. Rerun `./tool/flutter.sh test
    --no-pub` in the normal Mac workspace before release.

## 2026-07-17 Native Map Launcher

- Reapplied as the fifth approved post-`2.5.17` item. Events with a non-empty
  location show one `지도 바로가기` action.
- The action does not open a Flutter dialog or bottom sheet. It calls the
  `daily/map_launcher` native platform channel instead.
- iOS checks KakaoMap, Naver Map, and Apple Maps URL schemes:
  - one installed map app opens directly;
  - two or more installed map apps appear in a native system action sheet;
  - no installed map app falls back to an Apple Maps web search.
- Android checks KakaoMap and Naver Map because Apple Maps does not ship as an
  Android application. One installed app opens directly, two use a native
  Android dialog, and no installed map app opens the Apple Maps web search.
- macOS always shows its native system chooser with KakaoMap, Naver Map, and
  Apple Maps. Windows shows only KakaoMap and Naver Map. The selected provider
  opens in the default web browser; desktop never attempts to detect installed
  map applications.
- iOS declares `kakaomap`, `nmap`, and `maps` query schemes. Android declares
  package-visibility queries for `kakaomap` and `nmap`.
- Verification:
  - `flutter analyze --no-pub` passed using an isolated writable Flutter home.
  - Added `test/core/maps/map_launcher_test.dart`, but Flutter test execution
    remains blocked before tests start because sqlite3 attempts to download a
    macOS native library from GitHub and this environment has no network.
  - An iOS debug build could not start because the restricted environment
    cannot write Xcode/SwiftPM caches and CoreSimulatorService was unavailable.
- Required manual verification before release:
  - iPhone/iPad: test zero, one, two, and three installed map-app states and
    confirm the action-sheet anchor works on iPad.
  - Android: test KakaoMap-only, Naver Map-only, both, and neither installed.
  - macOS: test all three native chooser actions and confirm each opens the
    selected provider in the system default browser.
  - Windows: test both native chooser actions and confirm each opens the
    selected provider in the system default browser.

## 2026-07-17 Android and Windows Apple Maps Exclusion

- Apple Maps is intentionally unavailable on Android and Windows.
- Android lists or opens only KakaoMap and Naver Map. When neither installed
  app is available, it falls back to Kakao Map in the browser.
- Windows native chooser lists only KakaoMap and Naver Map, both opening in
  the user's default browser.
- iOS and macOS retain Apple Maps support.

## 2026-07-17 Full UI Text Size and Release 2.7.0.3

- The release label is `2.7.0.3`: marketing version `2.7.0`, build number
  `3`. Apple builds must use `--build-name 2.7.0 --build-number 3`; iOS and
  macOS Xcode test targets also store `MARKETING_VERSION = 2.7.0` and
  `CURRENT_PROJECT_VERSION = 3`. Windows MSIX uses `2.7.0.3` and the matching
  output filename.
- Removed the user-facing monthly event-density control from both Settings and
  the calendar filter sheet. The width-based standard display capacity remains
  fixed: `4` event lanes at widths up to `390`, `5` up to `430`, then `6`, `7`,
  `8`, `9`, `10`, and `12` as the viewport widens.
- Added the synced `appTextSize` setting with two values only: `기본` (`0.8x`)
  and `크게` (`1.0x`). `DailyApp` applies it through the root `MediaQuery`, so
  the onboarding, calendar, settings, dialogs, sheets, event details, and
  other app UI all inherit the same scale. The old
  `calendarEventTextSize` key is read only as a migration fallback, then
  removed when settings are saved.
- Existing local `calendarDensity` data is removed on the next settings save;
  it is no longer written to Google Drive AppData settings. Older remote
  settings without `appTextSize` safely use `기본`.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/features/calendar/calendar_month_grid_test.dart`
- Manual verification needed on iPhone 17, Android, macOS, and Windows:
  switch `기본`/`크게`, restart the app, then sync and restore on another
  platform to confirm the selected size remains unchanged and the old density
  selector is absent from both Settings and filter.

## 2026-07-17 Text Size Persistence (Issue #20)

- Issue #20 originally reported that the monthly event-density selection
  returned to its default. The density selector no longer exists in 2.7.0.3;
  its current user-facing replacement is the synced `전체 UI 글자 크기`
  (`appTextSize`) setting.
- Local `기본`/`크게` persistence was verified through a repository reload.
- Fixed a compatibility restore bug: a legacy Google Drive settings payload
  without `appTextSize` or `calendarEventTextSize` was decoded as `기본` and
  could overwrite a locally selected `크게` value. Legacy payloads now retain
  the local selection. A remote payload that explicitly contains a text-size
  value still restores that value across devices.
- Shared Flutter behavior applies to Android, Windows, iOS, and macOS. Manual
  platform verification should select `크게`, restart the app, restore an old
  Drive settings file, and confirm the selection remains `크게`; then restore
  a current backup with an explicit value and confirm that value is applied.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` (29 tests)

## 2026-07-17 Private Event Protection and Details (Issue #21)

- Private events are locked at the start of every app session and lock again
  when the app becomes inactive, hidden, or paused.
- Settings now exposes `비공개 일정 표시`. Enabling it requires device
  biometrics when available, with the saved Daily app-lock PIN as fallback.
  Disabling it immediately masks private content again.
- Locked private events use a neutral lock treatment. The title, time, D-day,
  location, map action, URI, weather, and memo are not rendered in month,
  week, day/full-date lists, quick access, or search results.
- Tapping a locked private event requires authentication. Tapping an unlocked
  event opens a detail sheet containing time, location, map shortcut, URI,
  weather, memo, D-day, and edit/delete actions.
- Fixed the intermittent URI/weather/memo loss at its sync race root cause.
  A Drive upload that completes after a newer local edit no longer saves its
  stale event snapshot over the database. It marks only the exact uploaded
  revision as synced; a newer revision remains pending for its own upload.
- Shared Flutter behavior applies to Android, Windows, iOS, and macOS. Manual
  verification after all planned issues:
  - Confirm private placeholders reveal no time or other metadata in every
    calendar view, quick access, search, and the full-date list.
  - Confirm biometric and PIN access, cancellation, incorrect PIN, session
    unlock, manual re-lock, and background re-lock.
  - Confirm the detail sheet actions, map chooser, URI opening, recurring-event
    edit scopes, and deletion.
  - Edit URI, weather, and memo repeatedly while Drive sync is active and
    verify the newest values survive locally and on another device.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - Focused calendar, event-detail, sync, and app widget tests (38 tests)
  - Full `./tool/flutter.sh test --no-pub` suite (60 tests)

## 2026-07-17 Quick View Tab and Today Navigation (Issue #22)

- `빠른 보기` no longer opens a modal sheet. It is now a selected bottom-bar
  tab that replaces the main content while keeping the bottom bar visible.
- The quick-view cards keep their existing destinations: monthly summary opens
  month view, today's events open day view at today, and D-day opens the
  filtered month view.
- The LLM button intentionally retains its existing modal input sheet. Issue
  #22 applies tab navigation only to quick view.
- Added an always-visible `오늘` header action to week, month, and day views on
  compact iPhone/iPad layouts as well as desktop layouts. It keeps the current
  calendar mode and moves the selected date and visible month to today.
- Removed the duplicate quick-view header action because quick view is now a
  primary bottom tab.
- Manual verification after all planned issues: switch repeatedly between
  quick/week/month/day, verify selected bottom-bar styling, confirm quick-view
  card destinations, confirm LLM still opens its sheet, and test the today
  action in all three calendar modes on compact and wide layouts.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - Full `./tool/flutter.sh test --no-pub` suite (60 tests)

## 2026-07-17 App Lock UX (Issue #19)

- Replaced system-keyboard PIN entry on the lock gate with an in-app numeric
  keypad. The unlock action button is removed; entering the final configured
  PIN digit verifies and unlocks immediately.
- New PINs remain 4 digits or longer. Their exact length is stored separately
  in secure storage beside the PIN hash, so 4, 5, 6, or longer PINs all verify
  precisely on their final digit. Legacy PIN hashes without a saved length use
  a short pause-based compatibility check once, then save their length after
  a successful unlock.
- Enabling lock now uses a custom numeric keypad and confirmation step.
  Disabling lock first requires a successful PIN verification and disables
  the biometric preference with the lock.
- Added an optional `생체 인증 사용` setting. The shared app flow uses the
  official `local_auth` plugin and falls back to PIN when biometric auth is
  unavailable, cancelled, or fails. Android now uses `FlutterFragmentActivity`
  and an AppCompat theme as required by that plugin. Windows plugin generation
  is included for Windows Hello support.
- Shared Flutter code re-locks and clears entered PIN state whenever the app is
  inactive, hidden, or paused, preventing Settings from remaining usable after
  backgrounding.
- Android applies `FLAG_SECURE` whenever app lock is enabled, so Daily content
  is excluded from the recent-app preview and device screenshots.
- Follow-up fix: the lock gate now wraps the app's root Navigator instead of
  only the calendar home. Backgrounding from Settings, Search, event details,
  or another pushed route therefore covers that route immediately. The hidden
  Navigator remains mounted while locked, so successful PIN/biometric unlock
  returns to the route the user was viewing instead of losing navigation state
  or showing the lock only after returning to the calendar.
- Added a widget regression test covering unlock -> Settings -> inactive ->
  locked -> resume -> unlock -> restored Settings.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - `./tool/flutter.sh test --no-pub test/widget_test.dart test/core/sync/google_drive_sync_service_test.dart` (26 tests)
  - Added a test that verifies secure PIN hash/length storage and deletion.
- Android debug APK build could not run on this Mac because no Android SDK is
  configured.
- Mac/iPhone agent follow-up required before Apple release:
  - Run `flutter pub get` so `local_auth_darwin` is registered in generated
    native plugin files, then add/verify the Face ID usage description and
    test Face ID/Touch ID on real devices.
  - Implement native privacy overlays during app switching so iOS/macOS app
    switcher snapshots never expose Daily content while app lock is enabled.

## 2026-07-17 Bug Reporting (Issue #23)

- Added `버그 제보` under Settings > App Info. It opens the Daily GitHub new
  issue page in the user's default external browser.
- The report draft contains only the Daily version/build, platform, OS version,
  and blank sections for the symptom, reproduction steps, expected behavior,
  and actual behavior. Daily events, account details, memos, and other user
  data are never read or attached.
- Added a GitHub bug-report issue form with the same required sections and an
  explicit privacy confirmation.
- Manual verification after all planned issues: open the report action on
  Android, Windows, iOS, and macOS; confirm the default browser opens, the
  environment fields are accurate, cancellation returns safely to Daily, and
  no private calendar/account data appears in the URL or form.

## 2026-07-20 macOS Desktop Layout Correction

- macOS no longer renders the iOS five-item bottom bar. iOS keeps the existing
  bottom navigation unchanged.
- macOS keeps quick access as a main-content tab, but exposes quick access,
  week/month/day selection, and the LLM action in a desktop header toolbar.
- macOS maps the synced text-size choices to desktop-appropriate scales:
  `기본` is `1.0x` and `크게` is `1.15x`. Other platforms retain their existing
  scales.
- The initial macOS window content size is `1000 x 720`, with a minimum size of
  `800 x 600`.
- Five-week months render five rows instead of reserving an empty sixth row.
  At an `800 x 570` month-grid area, at least four event rows remain visible.
- Manual verification required after install: resize the macOS window between
  `800 x 600` and larger desktop sizes, switch quick/week/month/day, open LLM,
  and verify there is never a bottom navigation bar on macOS.

## 2026-07-20 Version 2.7.1

- Raised the user-facing release version to `2.7.1`. The current Flutter/Apple
  build metadata also resolves to `2.7.1`, so installed Apple builds display
  `2.7.1 (2.7.1)`.
- Windows uses the required four-part package version `2.7.1.1`.
- This version includes the macOS desktop layout correction: one-line header
  toolbar, no iOS-style bottom bar, desktop text scaling, dynamic month rows,
  and increased event visibility at the minimum window size.

## 2026-07-20 macOS Issue #24

- Added the Keychain Sharing entitlement required by
  `flutter_secure_storage` to both macOS DebugProfile and Release builds. This
  allows the app-lock PIN hash and configured PIN length to persist correctly.
- Added horizontal macOS pointer-scroll navigation to weekly and daily views.
  Vertical pointer scrolling remains available to the event lists and does not
  change the selected week or day.
- Restored monthly trackpad scrolling by removing a month-only drag-device
  override that excluded macOS trackpad input. The month view now uses the same
  full-area pointer listener pattern as week/day and still supports both
  horizontal and vertical two-finger month navigation.
- Previous/next controls now animate the week, month, and day PageViews instead
  of jumping directly to the target page. Repeated button input is guarded so
  an older animation cannot clear the state of a newer transition.
- Automated verification covers an intermediate animation frame, weekly and
  daily horizontal pointer navigation, and vertical-scroll date preservation.
- Manual macOS verification: configure and relaunch with app lock enabled;
  horizontally scroll week/day with a trackpad; vertically scroll long event
  lists; and use previous/next in every calendar view to inspect transitions.

## 2026-07-20 Google Session Persistence (Issues #25 and #27)

- Issues #25 and #27 are handled as the same persisted-session defect. An app
  update exposes the same path as a normal process restart: the OAuth service
  is recreated and must restore its durable credential without opening an
  interactive Google login window.
- Desktop OAuth storage no longer treats a missing Keychain entitlement as a
  successful read or write. A Google connection is accepted only after the
  refresh token and account email can be read back from secure storage.
- Refreshed access tokens are persisted before replacing the in-memory token.
  If account metadata was unavailable during restore, it is fetched again and
  persisted together with the refreshed token.
- iOS now includes the Keychain Sharing entitlement used by
  `flutter_secure_storage`. macOS DebugProfile and Release already received the
  same entitlement while resolving issue #24.
- Startup restore is non-interactive and serialized. When a Daily account has
  a linked Google identity, temporary restore failures are retried after 1, 3,
  and 8 seconds. Failure never blocks local calendar use and never deletes the
  saved Daily/Google account link.
- Android lightweight account restoration now allows 10 seconds instead of 3
  seconds. Android and Windows receive the shared startup retry behavior;
  Windows desktop OAuth also receives secure-storage write/readback
  verification.
- Automated verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - Full `./tool/flutter.sh test --no-pub` suite (69 tests)
  - iOS no-codesign device build
  - macOS debug build and code-sign verification
- Latest macOS test app installed at
  `/Users/kimhwi/Applications/Daily.app`.
- Manual platform verification still required:
  - Connect Google, fully terminate Daily, reopen it, and confirm sync resumes
    without a Google prompt.
  - Install an update over the connected app and repeat the same check.
  - Temporarily start offline, then restore the network within the retry
    window and confirm sync resumes without losing the linked account.
  - Run the above on real iPhone and Android devices and on Windows. This Mac
    environment verified builds and automated behavior but not those three
    runtime environments.

## 2026-07-20 Expandable Day Schedule Sheet (Issue #26)

- The compact calendar's selected-day schedule view is no longer fixed at 68%
  of the screen height. It uses a draggable sheet with a 68% initial height,
  40% minimum height, and 96% maximum height inside the safe area.
- Dragging upward expands the sheet first; at its maximum height, the same
  gesture continues scrolling the event list. The empty-day state uses the
  same scroll controller, so the sheet can still expand and collapse when no
  events exist.
- The existing add, open, edit, and delete actions remain unchanged.
- This is shared Flutter behavior for iOS, Android, macOS, and Windows. Manual
  verification should open days with zero, one, and many events; drag between
  minimum, initial, and maximum heights; scroll a long list at maximum height;
  and confirm the sheet respects notches, home indicators, and desktop window
  bounds.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - Focused `test/widget_test.dart` suite (26 tests)
  - Full `./tool/flutter.sh test --no-pub` suite (70 tests)

## 2026-07-20 Version and Build Display

- Settings > App Info now displays both the user-facing version and the native
  build number, for example
  `버전 2.7.1 (2.7.1) · com.littlebit0.daily.macos`.
- If a platform does not provide a build number, the UI falls back to the
  version-only label instead of showing empty parentheses.
- The version values themselves were not raised by this change. The project
  remains version `2.7.1`, current Apple build metadata `2.7.1`, and Windows
  package version `2.7.1.1`.
- The latest macOS test build was installed and launched from
  `/Users/kimhwi/Applications/Daily.app`.

## 2026-07-20 macOS Distribution-Equivalent Keychain Verification

- The macOS Xcode project was already configured for automatic Apple
  Development signing, but `tool/flutter.sh` replaced every debug build's
  valid signature with an ad-hoc signature after Flutter finished building.
  That removed the effective application identifier and caused Keychain error
  `-34018`, so Google OAuth credentials could not be restored or saved.
- Removed that post-build ad-hoc re-sign step. Flutter/Xcode now preserves its
  original Apple Development signature and embedded provisioning profile.
- macOS DebugProfile and Release entitlements now declare the concrete group
  through `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`. The resulting
  development build contains:
  - application identifier `A6Y73X2ZLS.com.littlebit0.daily.macos`
  - team identifier `A6Y73X2ZLS`
  - Keychain group `A6Y73X2ZLS.com.littlebit0.daily.macos`
  - Sign in with Apple entitlement
- Installed provisioning profiles were inspected:
  - `Mac Team Provisioning Profile: com.littlebit0.daily.macos` contains Sign
    in with Apple and the allowed `A6Y73X2ZLS.*` Keychain group.
  - The existing Mac App Store distribution profile allows the Keychain group
    but does not currently list Sign in with Apple. Refresh/regenerate that
    distribution profile before submitting a macOS App Store build.
- Runtime verification passed with the newly signed app:
  - the Keychain configuration error disappeared;
  - linked Google account `kimhui0407@gmail.com` restored without an
    interactive login window;
  - synced calendar data appeared;
  - after a complete process termination and relaunch, Settings still showed
    Apple and Google connected and a successful sync timestamp.
- Verification passed:
  - signed app and embedded provisioning profile inspection
  - `bash -n tool/flutter.sh`
  - `./tool/flutter.sh analyze --no-pub`

## 2026-07-21 Multiple Default Event Reminders (Issue #4)

- Clarified issue #4 as the Settings > `기본 일정 알림` default, rather than
  the already-supported per-event reminder selector.
- Replaced the single default-reminder dropdown with a shared cross-platform
  multi-select control. Users can combine start time, 10 minutes, 30 minutes,
  1 hour, 1 day, and custom minute values; selecting `없음` clears all default
  reminders.
- New events opened from the calendar and selected-day details receive every
  selected default reminder. Existing events retain their own saved reminder
  list when edited.
- Rule-based and Gemini-assisted quick entry receive the same default reminder
  list. A reminder explicitly written in the user's input replaces the defaults
  for that event.
- Settings now persist `defaultReminderMinutesList`. Existing
  `defaultReminderMinutes` values migrate to a one-item list, and the legacy
  field remains in Google Drive settings data for older-backup compatibility.
  Google Drive v2 backup/restore also stores and restores the full list.
- Event notification cancellation now includes every configured default value,
  preventing stale pending notifications after defaults change.
- Shared Flutter behavior applies to iOS, Android, macOS, and Windows. Manual
  verification on each platform should select several defaults, create an
  event through both the calendar and quick entry, restart the app, and confirm
  every selected reminder remains visible and is delivered separately.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - Full `./tool/flutter.sh test --no-pub` suite (77 tests)

## 2026-07-21 macOS App Store Identity and Signing

- macOS remains in the existing multi-platform DailyCalendar App Store Connect
  record and uses the same bundle identifier as iOS: `com.littlebit0.daily`.
- macOS `CFBundleDisplayName` is `DailyCalendar macOS`, and the Transporter file
  name explicitly contains `macOS`. Google Drive continues to use the existing
  macOS desktop OAuth path.
- A previous exported PKG mixed an Apple Distribution signature on `Daily.app`
  with Apple Development signatures on executable-free Swift Package resource
  bundles. Transporter rejected those nested bundles with error 90284.
- The macOS Xcode build now removes stale signatures only from `.bundle`
  resources that have no `CFBundleExecutable`, before Xcode seals and signs the
  outer app. Frameworks and bundles containing executable code are untouched.
- A fresh App Store PKG was generated and validated:
  - display name `DailyCalendar macOS`;
  - bundle ID `com.littlebit0.daily`;
  - version/build `2.7.1 (2.7.1)`;
  - Apple Distribution outer app signature and Apple-issued installer chain;
  - all 16 executable-free resource bundles contain no nested code signature;
  - `codesign --verify --deep --strict` passes;
  - application ID, Apple login, sandbox, network, and Keychain entitlements
    match `A6Y73X2ZLS.com.littlebit0.daily`.
- Current Transporter package:
  `/Users/kimhwi/Documents/Codex/2026-05-26/littlebit0-daily-https-github-com-littlebit0/dist/transporter-2.7.1/Daily-macOS-AppStore-2.7.1.pkg`
- Transporter uploaded this corrected macOS package to App Store Connect at
  2026-07-21 02:54 KST. The transfer completed successfully and entered Apple
  processing without the previous 16 error 90284 code-signing failures. Apple
  then rejected the duplicate macOS build number `2.7.1`, which had already
  been consumed by the earlier failed delivery.
- macOS now keeps marketing version `2.7.1` but uses its own App Store build
  number `2.7.2`. iOS remains unchanged. The macOS build number is declared as
  `MACOS_BUILD_NUMBER` in `macos/Runner/Configs/AppInfo.xcconfig` and must be
  incremented for every subsequent macOS upload attempt.
- To prevent selecting the adjacent iOS IPA in Transporter, the final macOS
  package was also copied to a macOS-only upload directory with the build
  number in its filename:
  `/Users/kimhwi/Documents/Codex/2026-05-26/littlebit0-daily-https-github-com-littlebit0/dist/transporter-macos-2.7.1/Daily-macOS-AppStore-2.7.1-build-2.7.2.pkg`.
- Transporter identified that package separately with the macOS application
  icon and metadata `2.7.1 (2.7.2)`. Its upload completed at 2026-07-21 03:21
  KST and entered Apple processing. The earlier iOS `2.7.1 (2.7.1)` duplicate
  failure remained as a separate card, confirming that the final delivery was
  the macOS build rather than another iOS IPA attempt.

## 2026-07-28 Version 2.7.3 and Issues #28/#31

- Raised the shared user-facing version and build label to `2.7.3 (2.7.3)`.
  - iOS and macOS bundle metadata both resolve to version `2.7.3`, build
    `2.7.3`.
  - Android uses version name `2.7.3` and the required integer version code
    `273`; Daily displays `2.7.3 (2.7.3)` in Settings.
  - Windows uses the required four-part MSIX version `2.7.3.3`; Daily displays
    `2.7.3 (2.7.3)` in Settings.
- Fixed issue #28 on the macOS quick-access toolbar. While quick access is
  active, the previous week/month/day segment is no longer left selected.
  Pressing that same segment now returns to its calendar view, matching the
  behavior of selecting either of the other views.
- Fixed issue #31 in the selected-day event panel. The event detail surface,
  edit button, and delete button now own separate hit-test regions. Edit and
  delete each use a stable 48-by-48 target, and the surrounding event body
  opens details without competing with those actions. This shared Flutter
  change applies to all four platforms.
- Added regression coverage for:
  - quick access -> same week/month/day segment restoration;
  - all four inset corners of the event body, edit target, and delete target;
  - matching user-facing version/build labels.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - full `./tool/flutter.sh test --no-pub` suite (78 tests)
  - iOS simulator debug build; built plist is `2.7.3 (2.7.3)`
  - macOS debug build; built plist is `2.7.3 (2.7.3)`
- Android could not be built locally because this Mac has no Android SDK.
  Windows cannot be built on macOS. GitHub Actions must verify both platform
  builds after these changes are pushed.

## 2026-07-28 Test App Identification and Local Cleanup

- Keep the App Store-installed macOS app at `/Applications/Daily.app` intact.
  It has the App Store receipt, display name `DailyCalendar macOS`, and bundle
  identifier `com.littlebit0.daily`.
- Removed the previously installed development app from
  `/Users/kimhwi/Applications` and removed the development app from the iPhone
  17 simulator. The simulator was shut down after cleanup.
- Debug builds are now visibly named `Daily Test` on iOS and macOS. Release and
  Profile builds keep their production names, so App Store packages are not
  renamed.
- macOS test builds must be installed at
  `/Users/kimhwi/Applications/Daily Test.app`. Do not replace or delete the App
  Store app when refreshing a test build.
- The test name is intentionally different while the production bundle
  identifier remains unchanged, preserving the existing Apple/Google signing
  and authentication configuration.
- Verification passed: `./tool/flutter.sh build macos --debug --no-pub`
  produced `build/macos/Build/Products/Debug/Daily Test.app`, whose display
  name and bundle name are both `Daily Test`.

## 2026-07-28 Version 3.0.0 Development Baseline

- Commit `fd2a8b5` preserves the completed `2.7.3` work before starting the
  next issue cycle.
- Raised the active development version and user-facing build label to
  `3.0.0 (3.0.0)` on iOS, macOS, Android, and Windows.
- Platform-required representations are Android version code `300` and Windows
  MSIX version `3.0.0.0`; both still display `3.0.0 (3.0.0)` inside Daily.
- Historical `2.7.3` release notes and artifact names remain unchanged.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`
  - settings version/build widget regression test

## 2026-07-28 Apple Home and Desktop Widgets

- The user assigned Android and Windows work to the Windows agent. This Mac
  task implemented only iOS/iPadOS and macOS widgets. Do not treat Android or
  Windows widget parity as completed by this change.
- Added a shared WidgetKit extension source with three production widgets:
  - `오늘 일정`: today's events in time order, in small and large families;
  - `주간 및 월간 캘린더`: a 7-day schedule in the short medium family and
    a 6-week month grid in the large family;
  - `D-day`: upcoming D-day events.
- The short medium widget family is reserved for the 7-day weekly schedule.
  Today, month, and D-day views must not expose alternative medium layouts.
- The weekly and month calendar views show event titles rather than color-only
  dots.
  - Weekly shows up to three titles per day and a `+N` count for additional
    events.
  - The large month grid shows two titles per day and a `+N` count for
    additional events.
  - Labels use the event category color as a subtle background. Sensitive
    titles remain exported as `비공개 일정`.
  - A continuous multi-day occurrence renders as one horizontal bar spanning
    its covered day columns. At a week boundary the bar continues on the next
    calendar row. Recurring occurrences retain distinct occurrence IDs and are
    not collapsed together.
- iOS/iPadOS exposes these widgets on the Home Screen. macOS exposes the same
  widgets through one WidgetKit extension in both Notification Center and the
  desktop widget gallery on macOS 14 or later.
- Flutter writes a privacy-safe event snapshot to a platform-appropriate App
  Group container and reloads WidgetKit after event create/update/delete,
  category changes, Drive restore, app start/resume, and local data reset.
  - iOS/iPadOS: `group.com.littlebit0.daily.widgets`.
  - macOS: `A6Y73X2ZLS.com.littlebit0.daily.widgets`. Apple documents this
    team-identifier form for macOS App Groups; it avoids the unrelated-app data
    permission prompt that occurred with the registered `group.` form in the
    local macOS test build.
- The snapshot is an atomically replaced `daily-widget-snapshot.json` file in
  the App Group container. Do not revert this to shared `UserDefaults`: the
  macOS widget extension was observed hanging in `cfprefsd` while reading that
  store.
- Sensitive event titles are always exported as `비공개 일정`. Hidden
  categories, deleted events, and disabled holiday events are excluded.
- Added the App Group entitlement to the iOS/macOS hosts and widget extensions.
  `tool/configure_apple_widgets.rb` idempotently creates and maintains the
  `DailyWidgets` iOS target and `DailyMacWidgets` macOS target.
- iOS/iPadOS Lock Screen widgets are implemented as additional families of the
  existing `오늘 일정` widget:
  - inline shows the next remaining event;
  - circular shows the count of remaining events today;
  - rectangular shows up to two remaining events and an `외 N개` count.
- Lock Screen widgets never show D-day or weekly/monthly content. Event titles
  use SwiftUI privacy redaction while times and counts remain visible. Events
  marked sensitive by Daily remain exported as `비공개 일정`.
- The shared snapshot includes timestamped schedule events so the extension can
  select the current day after midnight without requiring the app to relaunch.
  Widget timelines refresh at midnight and at event start/end boundaries.
- Runtime verification:
  - iPhone 17 simulator widget gallery found `Daily Test`;
  - the `오늘 일정` widget and the medium weekly widget were added to the
    iPhone 17 simulator Home Screen and rendered;
  - the iOS weekly widget was visually checked at its real Home Screen size:
    continuous events span their covered day columns as long bars, the current
    day highlight is visible, and labels do not clip;
  - macOS debug app was installed at
    `/Users/kimhwi/Applications/Daily Test.app` without touching the App Store
    app;
  - `pluginkit` registered
    `com.littlebit0.daily.widgets.macos (3.0.0)`;
  - the installed macOS host and embedded extension passed strict deep code
    signature verification;
  - the macOS host wrote a 4,322-byte real snapshot without a permission
    prompt, and WidgetKit Simulator loaded timelines in 0.04-0.16 seconds;
  - dark-mode WidgetKit rendering was checked for Today small, weekly medium,
    month large, and D-day small. Explicit foreground colors prevent the
    previous white-on-white text loss;
  - the weekly medium layout renders seven equal day columns, highlights today,
    and shows continuous events as long bars spanning their covered dates.
- Verification passed after the weekly widget and continuous-event fix:
  - `./tool/flutter.sh analyze --no-pub`;
  - full `./tool/flutter.sh test --no-pub` suite (81 tests);
  - iOS simulator debug build with the embedded `DailyWidgets.appex`;
  - macOS debug build with the embedded `DailyMacWidgets.appex`.
- Keep the iOS `Embed App Extensions` build phase before Flutter's
  `Thin Binary` phase. Flutter declares `Runner.app/Info.plist` as a Thin
  Binary output; reversing these phases creates an Xcode dependency cycle.
- Windows agent follow-up: implement and manually verify equivalent Android
  and Windows widgets separately. Do not edit Apple widget targets from the
  Windows workspace unless explicitly requested.

## 2026-07-29 Apple Event Alarms

- Implemented GitHub issue #17 for iOS/iPadOS using Apple's AlarmKit. This is
  a real system alarm that can ring when Daily is not running; it is not a
  relabeled local notification.
- Scope is deliberately limited to a single non-recurring user event:
  - timed events ring at their start time;
  - all-day events expose a separate alarm-time picker;
  - recurring-event alarms are disabled with a message that this behavior will
    belong to the future Routine feature;
  - read-only holidays are not schedulable as alarms.
- Existing event reminders remain available. When an event alarm is enabled,
  only the exact-start (`0` minute) reminder is replaced by AlarmKit; earlier
  reminders such as 10 or 30 minutes before are preserved.
- AlarmKit requests permission on the first iOS app start. On unsupported iOS
  versions or denied permission, the alarm control is disabled and explains
  the reason instead of silently falling back to a normal notification.
- Alarm presentation includes Stop and a 10-minute Snooze action. The alarm
  title includes the event title and a short memo excerpt. Sensitive events
  send only `비공개 일정` and never expose their title or memo to AlarmKit.
- Saving, editing, deleting, Drive-restoring, resetting, and account deletion
  cancel or reschedule the corresponding native alarm. Alarm settings are
  persisted in Drift schema version 5 and Google Drive v2 event JSON.
- Added an AlarmKit Live Activity to the existing iOS widget extension for the
  snooze countdown. Keep `DailyAlarmMetadata.swift` shared by Runner and
  DailyWidgets, and keep the iOS `Embed App Extensions` phase before Flutter's
  `Thin Binary` phase to avoid an Xcode dependency cycle.
- Verification passed:
  - `./tool/flutter.sh analyze --no-pub`;
  - full `./tool/flutter.sh test --no-pub` suite (86 tests);
  - iOS 26.5 simulator debug build with embedded DailyWidgets extension;
  - macOS debug build, confirming shared Dart changes do not break macOS;
  - iPhone 17 simulator displayed the real AlarmKit permission prompt;
  - after allowing permission, the event editor exposed the enabled timed alarm
    control and the all-day alarm-time picker;
  - a 03:20 test event rang as a native system alarm while Daily was fully
    terminated, showing the Daily app name, event title, Snooze, and Stop;
  - Snooze dismissed the alarm and entered the configured 10-minute snooze;
  - deleting the test event removed its pending native alarm.
- The live iOS check also exposed and fixed a pre-existing Flutter time-picker
  crash at Daily's `0.8` basic text scale. System time pickers now use the
  standard text scale, and a widget regression test opens their direct-input
  mode without a constraint exception.
- Remaining manual verification on a physical iPhone: verify audible alarm
  sound/vibration, Stop and 10-minute Snooze, and editing/deleting pending
  alarms. The simulator verified UI and scheduling behavior but cannot replace
  a physical-device audio test.
- Added the equivalent behavior supported by macOS through
  `UNUserNotificationCenter`. AlarmKit itself is unavailable on macOS, so this
  is a scheduled native macOS notification rather than an imitation AlarmKit
  interface:
  - it is scheduled for a timed event's start or an all-day event's selected
    alarm time and remains deliverable after Daily exits;
  - it uses the default alert sound and the time-sensitive interruption level;
  - its notification category exposes `10분 후 다시 알림` and `중지` actions;
  - Snooze removes the delivered notification and schedules the same content
    again in 10 minutes;
  - event edits, deletes, reset, and account deletion use the same cancel and
    reschedule path as iOS.
- The macOS event editor describes this platform-specific behavior instead of
  implying that it will show iOS AlarmKit's persistent full-screen alarm UI.
- A live macOS test exposed a partially completed schema-4-to-5 migration where
  `alarm_enabled` existed but SQLite's user version had not advanced. Migration
  5 now checks `PRAGMA table_info(event_records)` before adding each alarm
  column, preserving data and repairing the migration on the next launch.
- macOS native build, platform-channel wiring, editor rendering, and the
  partial-migration regression were verified locally. Android and Windows
  still show the feature as unsupported and need separate native designs if
  those platforms are brought into scope later.
- Final verification after adding macOS support:
  - `./tool/flutter.sh analyze --no-pub` passed;
  - the full Flutter suite passed with 89 tests;
  - macOS debug build passed with the native notification channel;
  - iOS simulator debug build passed, preserving the existing AlarmKit path;
  - the macOS editor reported notification authorization as available and two
    future alarms saved without a platform-channel error;
  - no notification banner was visible in the GUI snapshots after terminating
    both the production and test Daily processes. Treat audible delivery and
    the delivered Notification Center entry/actions as still requiring a
    manual macOS check; do not claim that portion as verified until observed.

## 2026-07-29 Calendar Data Import (GitHub Issue #29)

- Added `설정 > 달력 > 캘린더 데이터 옮기기` on iOS/iPadOS and Android.
- iOS/iPadOS imports Apple Calendar data through EventKit after requesting full
  calendar access. Google-backed EventKit calendars are excluded from this
  source so the same events are not also imported through Google Calendar API.
- Android imports Samsung Calendar data through `CalendarContract` after
  requesting `READ_CALENDAR`. The provider filter includes Samsung and Samsung
  local calendar accounts and excludes Google accounts.
- Google Calendar import is available on both platforms. It reuses the signed-in
  Google account when possible and requests the additional
  `calendar.readonly` OAuth scope only when the user opens the Google import
  source. Existing Drive AppData authorization remains included when the OAuth
  grant is refreshed.
- Users first load a source, select one or more calendars, and then import them.
  Imported data includes title, memo, location, URL, start/end, all-day state,
  supported recurrence interval/end/count, source calendar color, and popup or
  alert reminder minutes.
- Imported source events receive deterministic IDs based on provider, calendar,
  and source event ID. Re-importing skips an event already imported into Daily
  and does not overwrite later user edits.
- Import saves events in a batch: per-event notifications and sync upserts are
  scheduled, while morning briefing and WidgetKit refresh run only once after
  the batch. This avoids repeated full refresh work on large calendars.
- Verification completed on this Mac:
  - `./tool/flutter.sh analyze --no-pub` passed;
  - full Flutter test suite passed with 96 tests;
  - 7 focused calendar import tests passed;
  - iOS simulator debug build passed and was installed/launched on the existing
    iPhone 17 simulator.
- Required external configuration before production Google import testing:
  enable Google Calendar API for the production Google Cloud project and ensure
  the OAuth consent configuration permits
  `https://www.googleapis.com/auth/calendar.readonly`.
- Android SDK is not installed in this Mac workspace, so the Android APK could
  not be compiled here. A Windows/Android agent must build and manually verify:
  Samsung calendar discovery on a physical Samsung device, runtime permission
  denial/retry, timed and all-day event conversion, alert preservation, Google
  account consent, large imports, and duplicate re-import behavior.

## 2026-07-29 Active Platform And Test Install Rules

- From this point forward, this Mac agent must not edit Android or Windows
  implementation files. Work only on iOS/iPadOS, macOS, and shared code whose
  Apple-platform effects are intended by the user.
- Keep exactly one installed macOS test app at
  `/Users/kimhwi/Applications/Daily Test.app`. Before a future update, remove
  stray `Daily Test` previous/failed/partial copies and other Daily alarm test
  apps, then replace this one target with the new build so its external app data
  container remains available. Launch only when the user explicitly requests
  it.
- For the current iPhone simulator request, install the new build only. Do not
  launch it; the user will perform the launch and test manually.

## 2026-07-29 Imported Categories And Category Visibility

- Calendar import now creates one Daily category per selected source calendar.
  The category preserves the source calendar title and color, and every event
  imported from that calendar is assigned to it.
- Imported category IDs are deterministic from provider plus source calendar
  ID. Calendars with the same visible title remain separate when their source
  IDs or providers differ. Re-import preserves a category name or color that
  the user has subsequently customized in Daily.
- Category add/edit keeps the existing preset palette and adds one standalone
  rainbow palette icon without a labeled chip or visible button box. It opens
  an interactive color picker with a draggable saturation/value field and hue
  strip while retaining exact 0-255 red, green, and blue sliders and inputs.
- Every category row in Settings now has a calendar visibility checkbox.
  Clearing it stores the category ID in `hiddenCategoryIds`; month, week, day,
  quick view, search, and Apple widget snapshot filtering use this same setting.
  Deleting a category also removes its obsolete hidden-category ID.
- This work intentionally did not edit Android or Windows implementation files,
  following the active platform boundary requested by the user.
- Verification passed with `./tool/flutter.sh analyze --no-pub`, the full 97-test
  Flutter suite, an iOS simulator debug build, and a macOS debug build. The new
  builds were subsequently installed as updates to the single macOS test app
  and the existing iPhone 17 simulator app. Neither app was launched.
- After the interactive picker update, all 97 tests and both Apple debug builds
  passed again. `/Users/kimhwi/Applications/Daily Test.app` and the existing
  iPhone 17 simulator were updated without launching. The generated macOS Debug
  app was moved to Trash after installation so only one installed test app
  remains discoverable outside Trash.

## 2026-07-29 Category Color Race Fix

- Investigated intermittent cases where one or a few events retained an older
  category color after consecutive category edits. The event table update was
  already batched, but an in-flight Google Drive restore could save its earlier
  per-event snapshot after the local category update and overwrite only the
  events reached later in that restore loop.
- Google Drive restore now re-reads each local event immediately before saving
  a restored snapshot. A newer local event, or a different locally pending
  revision, is preserved and queued for upload instead of being overwritten.
- Category-wide event updates are serialized so a previous color change cannot
  finish after a newer one. The full settings backup triggered by category edit
  now starts only after all affected event records and sync queues are updated.
- Added a regression test that injects a newer local category color between the
  restore merge and final event save; the newer color and pending sync state are
  retained.
- Verification passed with `./tool/flutter.sh analyze --no-pub`, all 98 Flutter
  tests, an iOS simulator debug build, and a macOS debug build. The apps were
  not installed or launched during this investigation.

## 2026-07-29 Category Settings UI Correction

- Replaced the custom RGB palette icon with the same circular `ChoiceChip`
  shape used by the preset colors. Its circle uses a rainbow sweep gradient and
  has no palette glyph or separate rectangular icon-button treatment.
- The dark-screen freeze was reproduced in a widget test. `AlertDialog` asks
  for intrinsic dimensions, but the picker's nested `LayoutBuilder` cannot
  provide them, so Flutter added the modal barrier and then failed before
  painting the dialog body. Both picker regions now receive a precomputed,
  bounded width and contain no `LayoutBuilder`. Keyboard focus is also released
  before opening the picker.
- Moved each category visibility checkbox to the far-left leading position,
  before the category color dot. Edit, delete, and lock actions remain at the
  right.
- Added a regression test that opens category edit, taps the rainbow choice,
  and verifies the RGB dialog title and all three channel controls render.
  `./tool/flutter.sh analyze --no-pub` and all 99 Flutter tests passed. Fresh
  iOS simulator and macOS debug builds passed. The existing iPhone 17 simulator
  app and `/Users/kimhwi/Applications/Daily Test.app` were updated in place;
  neither was launched after installation.

## 2026-07-29 Unified Category Color Palette

- Replaced the separate saturation/value board and hue strip with one
  integrated color palette. Horizontal movement selects hue; vertical movement
  moves from white through the vivid hue to black.
- Exact RGB sliders and numeric inputs remain available below the palette.
- The RGB picker regression test now verifies that exactly one integrated
  palette is rendered, preventing the two-board layout from returning.
- `./tool/flutter.sh analyze --no-pub` and all 99 Flutter tests passed. Fresh
  iOS simulator and macOS debug builds passed. The existing iPhone 17 simulator
  app and `/Users/kimhwi/Applications/Daily Test.app` were updated; neither app
  was launched after installation.
- All preset and custom rainbow color choices now use an explicit `40 x 40`
  footprint with a circular button surface and circular selection state. The
  circular swatch artwork remains unchanged. The widget regression test verifies
  equal width and height, `CircleBorder`, and disabled checkmarks for every
  category color choice. Analysis and the focused widget test passed; fresh iOS
  simulator and macOS debug builds were installed without launching either app.

## 2026-07-29 Performance Optimization Pass

- Calendar range queries now filter unrelated one-time events in SQLite before
  mapping and recurrence expansion. A regression fixture with 120 historical
  events reduced recurrence-expander inputs from 122 records to the two records
  that can affect the requested month.
- Old daily and weekly recurrences now fast-forward directly to the first
  potentially visible occurrence while preserving recurrence count semantics.
  Monthly and yearly recurrence behavior was intentionally left unchanged.
- Solar-to-lunar conversions use a bounded 512-entry cache. The month grid also
  retains its visible-day, week, and holiday calculations across internal
  selection rebuilds.
- Category label/color updates no longer cancel and recreate every affected OS
  notification or morning briefing. Those values do not affect notification
  timing or content. Event sync queueing and Apple widget refresh remain intact.
- Apple widget refresh requests are coalesced while a refresh is in flight, and
  month events are grouped by date once instead of rescanning the full event
  list for all 42 cells.
- Verification passed with `./tool/flutter.sh analyze --no-pub`, all 103 Flutter
  tests, an iOS simulator debug build, and a macOS debug build. The existing
  iPhone 17 simulator app and `/Users/kimhwi/Applications/Daily Test.app` were
  updated; neither app was launched after installation.

## 2026-07-29 macOS Google Session Validation

- Investigated a macOS state where Settings still displayed the linked Google
  email, but automatic backup did not run and `지금 동기화` opened Google login.
  The Daily account-provider metadata had survived, while no usable Google
  OAuth session was available to authorize Drive AppData requests.
- Settings now treats linked account metadata and an authenticated Google Drive
  session as separate states. Startup attempts only a silent session restore
  and validates authorization headers without opening an interactive login.
- When metadata exists but the session is missing or invalid, Settings keeps
  the linked email visible, explains that authentication is required, and shows
  `Google 다시 연결` instead of the misleading `지금 동기화` action. Automatic
  synchronization resumes after one successful explicit reconnection.
- Added a widget regression test for linked Google metadata with unavailable
  authorization headers. Analysis passed, all 104 Flutter tests passed, and a
  new macOS debug build was installed at
  `/Users/kimhwi/Applications/Daily Test.app`.
- The first reconnection attempt reached Google's callback but token exchange
  failed because the latest local macOS build had not been compiled with the
  Desktop OAuth client secret required by this configured Google client.
- `tool/flutter.sh` now detects macOS build/run commands and, when no explicit
  secret was supplied, reads the existing user-only
  `~/Library/Application Support/Daily/google_desktop_oauth.json` with `plutil`
  and injects the credential as a Dart define. The value is never printed or
  committed. An explicitly supplied secret continues to take priority.
- Rebuilt and replaced `/Users/kimhwi/Applications/Daily Test.app`. The stored
  Google refresh token then restored silently, automatic sync completed, and a
  full app restart again restored the session without showing Google login.
  The GUI showed a new successful-sync timestamp and all 76 local event rows
  had `sync_status = synced` with no pending rows.

## 2026-07-29 Google Drive Backup and Restore Queue Fix

- Investigated macOS and iOS reports that backup/restore appeared to run
  indefinitely or did not apply. The shared synchronization queue returned the
  currently running request's future to later callers, so `지금 동기화` could
  report completion before its own queued backup/restore had executed.
- Every sync caller now waits for its own request. Equivalent pending restore,
  settings-backup, event-backup, and full-sync requests are coalesced, including
  all callers' completion futures, so lifecycle restores cannot create an
  unbounded duplicate queue.
- A settings backup no longer uploads every event. It uploads only the settings
  file; event creation, update, deletion, and conflict reconciliation upload
  only their pending event IDs. Manual full sync still performs backup first,
  waits the required three seconds, and then restores.
- Restore now processes only events actually downloaded from Drive. Local-only
  pending events are no longer incorrectly marked synced before upload. A local
  event newer than its remote copy is queued for one conflict-reconciliation
  upload, while an identical remote snapshot skips database writes and all
  notification/alarm cancellation and rescheduling.
- The existing Mac account exposed 42 locally newer events that the prior merge
  had incorrectly left marked synced. The corrected build uploaded them once;
  all 76 local rows are now synced. After that reconciliation, a real manual
  backup, three-second gap, and 76-file restore check completed in 17.8 seconds
  and updated the successful-sync timestamp.
- Verification passed with static analysis, all 107 Flutter tests, a macOS debug
  build, and an iOS simulator debug build. The final macOS build replaced
  `/Users/kimhwi/Applications/Daily Test.app` and passed real-account sync. The
  iOS build was installed as an update on the existing iPhone 17 simulator and
  was not launched.

## 2026-07-29 Category Color Sync Consistency Fix

- Investigated category colors that changed correctly on the editing device but
  did not remain consistent through Google Drive synchronization. Category
  definitions live in the settings file while every event also stores its own
  category color, and the prior category-edit path uploaded those two snapshots
  through separate asynchronous requests.
- Local settings now persist a sync-pending flag and monotonically increasing
  revision. A restore cannot replace a locally pending category/settings edit
  with an older remote settings file, and an upload only clears the pending flag
  when the uploaded snapshot still matches the latest local revision.
- Category add, edit, and delete now queue one pending-change backup after all
  local category/event mutations finish. That backup uploads affected event
  files first and the matching settings snapshot last, so repeated color edits
  converge on the final selected color rather than mixing revisions.
- Normal pending-change startup/exit synchronization now includes pending
  settings even when there are no pending events. Existing event merge logic
  still detects remotely stale event colors and queues those event IDs for a
  corrective upload.
- Added regression coverage proving that an event file and settings file upload
  the same final category color and that restore preserves a locally pending
  category color. Static analysis and all 109 Flutter tests passed.
- Fresh macOS and iOS simulator debug builds passed. The macOS build replaced
  `/Users/kimhwi/Applications/Daily Test.app`; a real-account manual sync
  completed successfully and left all 76 local records synced with category
  colors matching their definitions. The iOS build updated the existing iPhone
  17 simulator app without launching it.

## 2026-07-29 Client-Only Cross-Device Change Detection

- The user explicitly rejected adding a server. Cross-device detection uses
  only the Google Drive Changes API from the client; no webhook, push server,
  background polling loop, or server infrastructure was added.
- Every sync envelope now includes a stable local `sourceDeviceId`. Each Google
  account stores its own Drive change page token locally. Daily checks that
  token at app start and foreground resume, ignores files written by the same
  device, and restores only detected writes from another device.
- On the first run after this migration, Daily obtains a Drive start-page token,
  performs one baseline restore, and stores the token. Subsequent automatic
  restores are incremental. iOS cannot receive an immediate remote wake while
  the app is terminated; remote changes are applied on the next app start or
  foreground resume.
- Lifecycle behavior is now:
  - Event create/update/delete uploads only the affected pending event files.
  - App start checks/restores remote changes first, then uploads persistent
    local pending changes.
  - Foreground resume uploads pending events/settings, waits three seconds, and
    then checks the Drive change feed for another device's writes.
  - Background/exit remains best-effort backup-only.
  - Manual sync remains backup, three-second wait, then full restore.
- Resume and manual backup upload settings only when the local settings pending
  marker is set. This prevents an unchanged, stale local settings snapshot from
  overwriting newer settings written by another device before change detection.
- Existing remote event files are compared immediately before upload. If an
  external device has a newer event revision, Daily applies that revision and
  does not overwrite it. Equal-time divergent revisions use device IDs as a
  deterministic tie-breaker.
- Duplicate requests continue to merge while every caller waits for its own
  completion. Network, timeout, rate-limit, and transient server failures keep
  event/settings pending state and use bounded retries at 2, 10, and 30 seconds.
  Authentication failures and interactive cancellation are not reported as a
  successful sync and never open a login window automatically.
- Added regression coverage for external-only change restoration, same-device
  filtering, baseline token persistence, backup-before-detect ordering, stale
  settings overwrite prevention, concurrent event conflict resolution, queued
  callers, offline retry bounds, and partial-batch retry behavior.
- Verification passed with `./tool/flutter.sh analyze --no-pub`, all 119 Flutter
  tests, a macOS debug build, and an iOS simulator debug build. Neither build was
  installed or launched for this change. No Android or Windows platform file
  was edited.

## 2026-07-29 GitHub Issue #32 Apple Platform Work

- Fixed the iOS private-event crash by declaring the Face ID usage purpose.
- Unified app and private-event locking around three exclusive methods:
  confirmation without a PIN, a Daily PIN, or Apple system authentication.
  macOS no longer opens Touch ID over the PIN keypad, and iOS/macOS system
  authentication permits the device passcode/password fallback.
- Private-event hiding now applies to both screens and notifications. New
  private events cannot be enabled until app locking is configured.
- PIN setup reveals one dot per entered digit instead of six empty dots. Unlock
  still remembers and verifies the saved PIN length immediately.
- Removed repeated category helper subtitles. Added an Apple-only setting to
  show or hide adjacent-month dates; hiding also clips adjacent-month event
  spans. The setting is persisted and included in Drive settings sync.
- Replaced only the iOS bottom bar with a floating circular control: a calendar
  view menu and a draggable quick/calendar/AI switch. Its selected control grows
  only until another screen interaction. macOS keeps its header toolbar.
- Verified both provider directions: Apple sign-in silently restores only an
  already linked valid Google session, while Google sign-in preserves the
  linked Apple identity. No server or interactive automatic login was added.
- The Daily version row now says `더블 클릭하여 Github 확인하기` and opens the
  repository only on double click.
- Replaced the UI text-size dropdown with a three-position slider and added
  `더 크게`. Adjusted month event layout so the today marker does not overlap
  the first event while preserving iPhone density and four macOS event rows.
- Verification passed with static analysis, all 132 Flutter tests, an iOS
  simulator debug build, and a macOS debug build. The builds were not installed
  or launched. No Android or Windows platform implementation file was edited.

## 2026-07-29 Sync Data-Loss Recovery And Directional Actions

- A sync incident left the current macOS/simulator database at 52 active and 25
  deleted records. A read-only USB backup of the App Store iPhone build was
  preserved at
  `/Users/kimhwi/Documents/Daily-Recovery-20260729-172915/physical-iphone-appstore-daily.sqlite`.
  It passed SQLite integrity checking and contains 55 active and 21 deleted
  records. Three events are active on the iPhone backup but tombstoned in the
  damaged synced database. Do not discard this recovery directory.
- Root cause in the client was a direction violation in
  `_backupQueuedEvents`: when a newer remote revision was found during a backup,
  the backup path replaced local data with that remote revision. A remote
  tombstone could therefore delete an active local event during an operation
  presented as backup.
- Backup no longer mutates local data. A newer remote conflict leaves the local
  event pending and reports `일부 백업 보류 · 먼저 복원 필요`; only an explicit
  restore path can apply remote data.
- Settings now shows `백업` and `복원` as two buttons in one row. Backup flushes
  local pending changes only. Restore is separately confirmed and then downloads
  Drive AppData while retaining newer or pending local revisions.
- Static analysis passed. All 27 Google Drive sync tests passed, including a new
  remote-tombstone regression test. The focused backup/restore row interaction
  test also passed. Apps were deliberately not launched while recovery data was
  being protected.
- The corrected `3.0.0 (3.0.0)` debug build replaced
  `/Users/kimhwi/Applications/Daily Test.app` and updated the existing iPhone 17
  simulator installation without launching either app. Both live databases were
  copied to
  `/Users/kimhwi/Documents/Daily-Recovery-20260729-172915/pre-restore-20260729-181638`
  before recovery.
- An initial three-record repair was superseded by the user's required full
  restore. macOS and the iPhone 17 simulator were both replaced transactionally
  from the complete physical iPhone App Store database and preference backup.
  Device-specific `deviceId` and Drive change tokens were retained independently
  to avoid creating another cross-device identity collision.
- Both restored databases pass integrity checks and exactly match all 76 source
  event IDs and logical event fields: 55 active records, 21 historical
  tombstones, zero missing records, zero extra records, and zero logical field
  differences. Full pre-restore snapshots are under
  `/Users/kimhwi/Documents/Daily-Recovery-20260729-172915/pre-full-restore-20260729-182401`.
- Every restored record and the restored settings were marked pending with a
  current conflict-winning revision. macOS successfully uploaded the full set
  of 76 records and settings to Drive and now reports all records synced. The
  simulator contains the complete same data locally; its 76 records remain
  pending because that simulator currently has no restorable Google auth
  session and therefore requires user Google authentication before it can
  upload independently.

## 2026-07-30 Login, Privacy Removal, And Lock Follow-Up

- macOS forced Google account changes now clear the cached desktop session and
  send `prompt=select_account consent`, so choosing a different Google account
  does not reuse the previous OAuth identity silently.
- Account logout now attempts a pending local backup, stops the sync worker,
  signs out local Apple/Google sessions, deletes local events and settings, and
  returns to onboarding. Google Drive AppData is retained. If the final backup
  fails, the user must explicitly approve continuing without it.
- The private-event feature was removed completely from the event model, edit
  and detail UI, calendar/search rendering, notifications, alarms, widgets,
  settings, and sync payloads. Database schema 6 rebuilds the event table
  without the old `sensitive` column while preserving every event row.
- App lock now offers three explicit methods before activation: PIN-free
  privacy covering, Daily `PIN 잠금`, or Apple system authentication. PIN-free
  mode has no unlock button and automatically reveals the app on foreground
  return. System mode authenticates before activation and automatically asks
  for system authentication on return. Changing or disabling a method first
  verifies the current method.
- PIN lock alone offers an optional biometric-unlock toggle. PIN entry remains
  the fallback. The persisted biometric flag now represents that PIN supplement
  rather than the system-lock method itself.
- Settings now uses `일 [토글] 월` for week start. Lock method and whole-app text
  size use thick three-position capsule controls with their option labels inside
  the control and support both tapping and horizontal dragging.
- iOS keeps the calendar-only view selector on the left, now as a draggable
  `주/월/일` three-position capsule instead of a popup menu. The central
  quick/calendar/AI control visibly enlarges only the most recent action and
  shrinks when another screen interaction begins. macOS retains its header
  toolbar and does not receive the iOS bottom bar.
- A backend-backed Daily identity link is intentionally not implemented yet.
  Restoring Apple-to-Google or Google-to-Apple provider links on a different
  device requires a real HTTPS service that verifies Apple identity tokens and
  Google ID tokens and stores provider-subject mappings in one Daily account.
  Do not simulate this with local preferences. Ubuntu deployment setup remains
  a user-managed follow-up.
- Verification passed with `./tool/flutter.sh analyze --no-pub`, all 130 Flutter
  tests, a macOS debug build, and an iOS simulator debug build. Neither app was
  installed or launched in this step. Android and Windows platform files were
  not edited.

## 2026-07-30 macOS Lock Runtime Fixes

- System-lock authentication no longer restarts after a successful result when
  macOS emits a trailing foreground lifecycle event. Authentication performed
  while enabling, disabling, or changing a lock setting is now explicitly
  excluded from ordinary app-background locking, preventing the extra unlock
  prompt seen when changing from PIN-free lock to system lock.
- macOS now installs a native window privacy overlay while Daily is inactive.
  PIN-free mode displays `잠금 상태에서는 화면을 볼 수 없습니다.`; PIN and
  system modes display `잠금 상태입니다.`. The overlay is removed when the app
  becomes active and the Flutter lock gate then applies the selected unlock
  policy.
- PIN lock initially shows only `잠금 상태입니다.` and a
  `비밀번호를 통해 잠금해제` button. The keypad appears after that button is
  selected. macOS also accepts number-row/numpad digits and Backspace/Delete
  from the hardware keyboard, while the saved PIN length is still verified
  immediately.
- PIN biometric unlock on macOS uses LocalAuthentication's
  biometrics-or-companion policy, supporting Touch ID or an enabled Apple Watch
  instead of forcing Touch ID-only authentication. iOS remains Face ID/Touch ID
  biometric-only for the optional PIN shortcut.
- Verification passed with static analysis, all 132 Flutter tests, macOS native
  debug compilation, and iOS simulator debug compilation. The latest `3.0.0`
  build replaced `/Users/kimhwi/Applications/Daily Test.app` and updated the
  retained iPhone 17 simulator app without launching either app. Temporary and
  build-cache macOS Daily app bundles were deleted afterward; only the App Store
  app and the installed test app remain as macOS Daily applications.

## 2026-07-30 Lock Fallback And iOS Control Follow-Up

- macOS PIN biometric unlock is attempted only once per lock session. If the
  user cancels the Touch ID/Apple Watch sheet or selects the password fallback,
  Daily immediately returns to its PIN entry UI and does not reopen the system
  biometric sheet on the trailing foreground lifecycle event.
- The app-unlock PIN indicator now adds one filled circle for each entered
  digit instead of drawing every empty PIN position in advance. macOS hardware
  keyboard and on-screen keypad input use the same indicator.
- Week start no longer uses a boolean-style `Switch`. Settings now presents a
  two-position `일/월` sliding capsule using the same visual and drag behavior as
  the lock-method capsule on both macOS and iOS.
- The iOS bottom controls are laid out as two non-overlapping controls: the
  calendar-only `주/월/일` slider on the left and the quick/calendar/AI slider on
  the right. The central slider uses the same capsule thumb and drag animation;
  its whole width expands from 132 to 164 points for the most recent bottom-bar
  action and collapses after another calendar/search/settings interaction.
  Icon-only scaling was removed. The left slider remains hidden outside the
  calendar view.
- Verification passed with static analysis, all 133 Flutter tests, macOS debug
  compilation, and iOS simulator debug compilation. Version `3.0.0 (3.0.0)`
  replaced `/Users/kimhwi/Applications/Daily Test.app` and updated the retained
  iPhone 17 simulator app without launching either app.

## 2026-07-30 iOS Bottom Slider Alignment Follow-Up

- The quick/calendar/AI slider is centered on the full screen again instead of
  being right-aligned. Its center remains fixed while its overall width expands
  from 132 to 164 points.
- The left `주/월/일` slider calculates the space beside the centered control
  and shrinks only when necessary, preventing overlap without displacing the
  center control.
- Both sliders use a visible 40-point circular blue selection thumb. Horizontal
  dragging previews the destination by moving that circle before committing the
  selected item.
- Tap ripple rendering now occurs inside a clipped transparent Material within
  each slider, so the animation cannot paint behind or outside the control.
- Tests use a 393-point iPhone viewport and verify exact center alignment,
  compact left-slider sizing, and both circular thumb dimensions. Static
  analysis and all 133 tests passed. The iOS simulator debug build succeeded and
  updated the retained iPhone 17 simulator without launching it.
- A follow-up fixed the left slider being hidden behind the center slider: the
  bottom `Stack` now explicitly fills the available width while an inner
  `Align` preserves the center slider's own 132/164-point width. When horizontal
  space requires compaction, the left slider now scales its height, circular
  thumb, and labels vertically as well as reducing its width. The iPhone 17
  simulator was rebuilt, updated, relaunched, and visually confirmed with the
  left `주/월/일` slider visible and existing calendar data intact.
- The center quick/calendar/AI control now also scales the outer capsule
  vertically: its inactive size is `132x40`, and selection or horizontal drag
  expands the actual control to `164x48`. This is outer-control resizing, not
  just icon or thumb scaling. Widget tests verify all four dimensions.
- The left `주/월/일` control now has the same interaction model. Its inactive
  outer capsule is `76x40`; tapping or beginning a horizontal drag expands it
  toward `96x48` (further constrained proportionally only when screen space is
  insufficient). Interacting with the center control or any other screen area
  collapses it again. The center control remains collapsed while the left
  control is selected, and vice versa.

## 2026-07-30 Issue 34 Appearance And Onboarding

- Added app theme selection with the `자동/화이트/다크` capsule. The selected
  theme is persisted locally, included in Google Drive settings sync, and
  applied through separate light/dark Flutter themes.
- Added the exact `좌우 슬라이드/상하 스크롤` month-navigation setting. The
  horizontal mode preserves the existing month paging. The vertical mode uses
  free vertical scrolling; when adjacent dates are enabled, a boundary week is
  owned by only one month so the dates continue without duplication. When
  adjacent dates are disabled, each month retains its own boundary cells.
- Non-boolean setting choices now use the shared draggable capsule UI. The
  default calendar view and 12h/24h format were converted; actual ON/OFF
  settings remain switches.
- Replaced the single-page welcome UI with three screenshot-based feature
  pages and a final account/start page. It supports swipe, previous, next,
  page indicators, and skip without changing Apple/Google/local start logic.
- Static analysis, 71 focused widget/sync tests, iOS simulator compilation,
  and macOS debug compilation passed. No Android or Windows platform file was
  edited. Because the settings model and onboarding are shared Flutter code,
  Android and Windows still require later visual and build verification.

## 2026-07-30 Dark Theme Completion

- Removed fixed light surfaces from event details, inline/full search results,
  the quick-entry bar, month/year selection, calendar range highlights,
  overflow counters, weekday cards, and detail-row icons. These components now
  derive surfaces, borders, text, and selection colors from `ColorScheme`.
- The dark theme now explicitly covers app bars, cards, dialogs, bottom sheets,
  popup menus, snackbars, date/time pickers, list tiles, and dividers instead of
  relying on individual Material defaults.
- Onboarding screenshots receive a dark multiply treatment in dark mode so the
  first-run carousel does not become a large bright panel. Apple sign-in
  black/white branding, calendar weekend colors, today's white-on-blue date,
  and RGB picker white/black endpoints intentionally remain fixed.
- Static analysis and 54 focused calendar/event/widget tests passed. The iPhone
  17 simulator was rebuilt, updated, and visually checked in dark mode on the
  weekly calendar and Settings. The macOS test app was rebuilt, replaced, and
  visually checked on the weekly calendar and day-details pane. Both latest
  test apps remain installed and running for user inspection.

## 2026-08-02 Calendar Navigation And Settings Follow-up

- The macOS horizontal year overview now responds to mouse-wheel and trackpad
  scroll input. Mini-month grids no longer create nested scrollbars.
- The iOS/macOS vertical year overview now uses ordinary continuous scrolling
  instead of moving exactly one year per gesture.
- Vertical month navigation always hides adjacent-month dates. Hidden boundary
  cells cannot be selected by a tap, while range hit-testing still permits a
  drag selection to extend into those previous/next-month boundary dates.
- Vertical month boundaries now use a large, left-aligned month label. The
  adjacent-date setting is forced off and disabled while vertical navigation
  is selected.
- Settings now opens account and notification options in dedicated second-level
  pages from the main Settings screen.
- The dark onboarding failure was caused by Flutter asset directories not being
  recursive. `assets/onboarding/dark/` is now explicitly bundled, and all three
  dark screenshots were confirmed inside both platform builds.
- Verification passed with `flutter analyze`, 52 focused widget/calendar tests,
  an iPhone 17 simulator debug build, and a macOS debug build. Visual checks
  confirmed continuous year scrolling, the month-boundary layout, Settings
  navigation, and the repaired dark onboarding image. The current iPhone 17
  simulator and `/Users/kimhwi/Applications/Daily Test.app` contain these
  changes.
- A follow-up prevents blank calendar cells, hidden adjacent-month cells, and
  month-boundary gaps from beginning, extending, or painting a range. Releasing
  over one of those areas cancels the pending selection.
- Vertical continuous month navigation now owns one shared range selection and
  hit-tests only the actual rendered date cells of each visible month. A drag
  can therefore start on an actual date, cross an unselectable blank gap, and
  resume when it reaches an actual date in the next month without painting the
  gap. The integration test verifies an August 31-September 2 range and the
  resulting event-editor dates.
- The two iOS bottom capsule controls no longer use mismatched Material ink
  splashes. Both use the visible selection circle itself for identical press,
  movement, and release animation. The iPhone 17 simulator and macOS test app
  were rebuilt and updated after this change; analysis and all 52 focused tests
  passed again.
- The selection circles in both iOS bottom sliders are positioned from the
  exact center of each three-way segment instead of stadium-edge alignment.
  This fixes the quick-access active color appearing off-center. A widget test
  checks the quick-access icon and selection-circle centers within half a
  logical pixel. Analysis and all 53 focused tests pass; the macOS test app and
  iPhone 17 simulator were rebuilt and updated with this final behavior.
- Every visible continuous date-range segment now has rounded outer corners.
  Adjacent selected dates in the same week remain one filled segment, while
  week rows, hidden cells, blank month gaps, and month boundaries visually
  separate segments and therefore round both ends independently. A regression
  test covers both the August and September sides of an August 31-September 2
  selection. Analysis and all 54 focused tests pass; both Apple test builds
  were rebuilt and updated.
- The year overview no longer maps the first preceding vertical sliver to
  `anchorYear - 200`; the nearest previous row now contains the immediately
  preceding year or year pair on both macOS and iOS. Regression tests cover
  both platforms.
- On macOS, wide year overviews show two years per row instead of stretching a
  single year across the window. Year rows are capped at 680 logical pixels so
  taller windows reveal more year information instead of scaling each mini
  calendar indefinitely. Each mini calendar now bases its internal column
  count on its allocated width rather than the full window width.
- The dark theme's lowest surfaces are true black (`#000000`). Higher surfaces
  use the preserved hierarchy `#050608`, `#0A0B0D`, `#11141A`, and `#1B2029`,
  with borders lowered to `#232832`. Theme tests pin the key RGB values.
- Static analysis and all 47 app widget tests pass. The macOS test app was
  rebuilt and visually approved by the user, and the iPhone 17 simulator app
  was rebuilt and updated for user verification without further UI actions.
- Both iOS bottom slider thumbs now derive their size and segment center from
  the track's actual per-frame inner constraints. This keeps the active circle
  synchronized with the `40 <-> 48` height animation. Both tracks use
  `Clip.none`, so the moving active color cannot be cut during the brief frame
  where position and size animations overlap. Widget tests pin the collapsed
  and expanded circle sizes and verify that neither track clips its thumb.
- Static analysis and all 47 app widget tests pass after the slider fix. The
  iPhone 17 simulator test app was rebuilt and updated without launching it.
- The year overview AppBar no longer displays the currently visible year or
  year range; individual year sections remain labeled. The macOS test app was
  rebuilt and replaced with this change.
- macOS year-overview resize frame drops were investigated but intentionally
  not optimized yet. Every window-size update invalidates the route-level
  `MediaQuery`, the year-grid `LayoutBuilder`, each allocated year
  `LayoutBuilder`, and all visible mini-month layouts. A wide vertical viewport
  can keep several two-year rows alive at once; each year builds 12 mini months
  and each mini month lays out 42 date slots. The one/two-column breakpoint at
  1000 logical pixels also replaces the full visible grid structure. These are
  the primary rebuild/layout pressure points for a future focused optimization.
- Static analysis and all 47 app widget tests pass after removing the year
  overview title. No resize-performance behavior was changed in this step.
- The macOS year overview resize path is now optimized. Each mini month paints
  its title, weekday labels, and 42-slot date grid in one custom paint layer
  instead of constructing a nested widget tree for every date. Year layout
  breakpoints are derived from the overview body constraints, and obsolete
  visible-year scroll tracking was removed after the AppBar year title was
  removed, preventing full-page rebuilds during year scrolling. The month tap
  target, accessibility label, today marker, one/two-column breakpoint, and
  year-row sizing behavior remain intact. Static analysis and all 47 app widget
  tests pass.
- The iOS week/month/day slider no longer clips its active circle at the week
  or day edge; the inner thumb layer now allows overflow just like its track.
  The center quick-view/calendar/AI slider is slightly narrower (`124` compact,
  `152` expanded) to reduce the side space around quick view while remaining
  centered. Its thumb layer also explicitly disables clipping.
- AI entry no longer opens a modal bottom sheet. It uses the same in-page
  animated-size approach as search, rising from the bottom and resizing the
  calendar content above it. Search and AI are mutually exclusive, the panel
  has an explicit close button, and the same inline behavior is available from
  the macOS toolbar. Static analysis and all 47 app widget tests pass; the
  iPhone 17 simulator build was updated without launching it.
- Fixed a macOS year-overview regression introduced by the mini-month painter
  optimization: a flex row supplied loose vertical constraints, so the canvas
  selected zero height and all six date weeks painted on the same line. Each
  mini-month canvas now explicitly expands to its allocated cell. A regression
  assertion requires a real calendar-cell height, all 47 widget tests pass, and
  the rebuilt macOS test app was visually verified with all six weeks visible
  across January through December.
- The same expanded mini-month canvas fix is included in the iOS build, so all
  six date weeks render in the iOS year overview as well. The iOS calendar
  period button now uses only its compact content area at the left of the
  header, capped at 120 logical pixels with a 44-pixel touch height. The space
  between it and the existing right-side actions is an intentionally empty,
  non-interactive reserved area. Static analysis and all 47 widget tests pass;
  the iPhone 17 simulator build was updated without launching it.
- Tapping the already-selected segment while either iOS bottom slider is
  expanded no longer briefly collapses and re-expands the whole control. The
  page-level pointer handler now excludes the bottom bar's actual render bounds
  from its "other interaction" collapse behavior. Selecting another segment,
  dragging, and interacting outside the bottom bar retain their existing
  expansion/collapse behavior. Mid-animation regression assertions cover both
  sliders; static analysis and all 47 widget tests pass.
- The AI panel performance path was reworked after the inline animated-size
  implementation produced a roughly 165.7 ms UI frame. The panel is now a
  paint-only slide/fade overlay above the bottom bar, AI and bottom-selection
  state use local value notifiers, and the calendar content has its own repaint
  boundary. An isolated debug VM timeline measured build at 6.972 ms maximum,
  layout at 5.872 ms maximum, and paint at 3.281 ms maximum. One 23.595 ms
  Vsync interval coincided with an 8.588 ms debug old-generation garbage
  collection, rather than recurring calendar layout work.
- iOS source and the generated simulator app both contain
  `CADisableMinimumFrameDurationOnPhone=true`. Daily is therefore configured
  to request ProMotion refresh rates above 60 Hz on supported devices. Actual
  frame cadence remains dynamically selected by iOS and must be measured on a
  physical ProMotion device in profile/release mode; the simulator cannot prove
  hardware 120 Hz operation. Static analysis and all 47 widget tests pass, and
  the rebuilt app was installed on the existing iPhone 17 simulator without
  launching it.
- Apple refresh-rate behavior is intentionally dynamic on both platforms. iOS
  retains `CADisableMinimumFrameDurationOnPhone=true`, allowing Flutter's
  `CADisplayLink` to use the display's supported maximum while iOS can still
  lower the active rate for Low Power Mode, thermal state, or static content.
  Flutter macOS binds its display link to the screen containing the app window
  and rebinds when the window changes screens, so a ProMotion Mac display can
  run at its current high refresh rate while a 60 Hz display remains at 60 Hz.
  No application-level fixed-fps timer or override is used. Regression tests
  now protect both the iOS plist setting and the absence of runner-level fixed
  frame-rate overrides. The focused configuration tests, static analysis, iOS
  simulator build, and macOS debug build all pass.
- Calendar content transitions now follow the fixed horizontal order
  `quick access -> week -> month -> day` on both iOS and macOS. Moving toward a
  later view slides the new content in from the right; moving toward an earlier
  view slides it in from the left. The transition includes quick-access and
  calendar content while leaving the iOS bottom controls fixed in place.
- macOS horizontal week, month, and day pointer navigation retains its page
  physics and uses the explicit 260 ms page animation path. Regression
  assertions inspect the content transition's mid-frame direction; iOS
  touch/swipe physics remain unchanged.
- The iOS and macOS calendar headers now live outside the ordered content
  switcher. They remain at the same coordinates while quick access, week,
  month, and day content slides underneath; the iOS header also remains visible
  on quick access instead of participating in the transition.
- On iOS only, when month navigation is set to `horizontal`, opening AI inserts
  the input panel immediately above the bottom bar. It retains the existing
  bottom-up presentation, grows upward, and reduces the calendar's available
  height instead of covering the calendar or occupying the search position.
  The panel restores the calendar height when closed. Vertical month scrolling
  and macOS retain the overlay AI presentation. Regression tests pin the fixed
  header rectangles and the inline panel/calendar height relationship. Static
  analysis and all 47 widget tests pass; both Apple test builds were rebuilt
  and installed without launching them.
- macOS vertical month navigation now smooths only physical mouse-wheel input.
  Its custom scroll position accumulates successive wheel targets and animates
  to them over 160 ms instead of applying each wheel notch as an immediate
  pixel jump. Trackpad pan/zoom scrolling remains on Flutter's original path
  and is not delayed or replaced. A regression test verifies that the wheel is
  still between its start and target after 40 ms and reaches the exact target
  after settling. Static analysis and all 47 widget tests pass; the rebuilt
  macOS test app was installed without launching it.
- Vertical month navigation now preserves the exact logical scroll position
  while the inline search panel opens and resizes the calendar viewport. The
  transient controller/extent correction is no longer interpreted as user
  scrolling, preventing the visible month from jumping several months
  backward. A regression test reproduces a partially scrolled month position,
  opens search through its full animation, and verifies both the visible month
  and fractional logical offset remain unchanged. Static analysis and all 48
  widget tests pass.

## 2026-08-02 App Store Connect 3.0.0 Upload

- Fixed the final vertical-month search regression: opening the inline search
  panel no longer treats viewport extent correction as user scrolling or moves
  the calendar several months backward.
- Verification passed before distribution:
  - `./tool/flutter.sh analyze --no-pub`
  - all 48 tests in `test/widget_test.dart`
  - the complete Flutter suite, all 142 tests
- Built, validated, and uploaded iOS `3.0.0 (3.0.0)` to App Store Connect.
  Apple accepted the upload and reported that the package is processing.
  - bundle ID: `com.littlebit0.daily`
  - widget ID: `com.littlebit0.daily.widgets`
  - local Transporter copy:
    `dist/transporter-ios-3.0.0/Daily-iOS-AppStore-3.0.0-build-3.0.0.ipa`
  - SHA-256:
    `172c9088c7c559d8e0a66229a5685b74b736274f5722dfff93457374d31eeac0`
- The first macOS upload attempt was stopped by App Store Connect validation
  error 90347 because the widget suffix `widgets.macos` contained two periods
  after the main app identifier. The macOS widget ID is now the valid shared
  identifier `com.littlebit0.daily.widgets`; the widget configuration generator
  was updated so regenerating the project cannot restore the invalid ID.
- macOS Release signing now applies Apple Development only to the app and
  widget archive targets. Swift Package resource bundles remain unsigned, and
  App Store export replaces the app/widget signatures with Apple Distribution.
- Built, validated, and uploaded the corrected macOS `3.0.0 (3.0.0)` package.
  Apple accepted the upload and reported that the package is processing.
  - app bundle ID: `com.littlebit0.daily`
  - widget ID: `com.littlebit0.daily.widgets`
  - all 16 executable-free resource bundles are unsigned
  - `codesign --verify --deep --strict` passes
  - local Transporter copy:
    `dist/transporter-macos-3.0.0/Daily-macOS-AppStore-3.0.0-build-3.0.0.pkg`
  - SHA-256:
    `fcd9f3e239f79c213b3902621cd158293fb4fe19724cfecb78c42e5a6c47778a`
- Remaining App Store Connect work: wait for both builds to finish processing,
  select each `3.0.0 (3.0.0)` build on its platform version page, verify export
  compliance and review metadata, add both to review, and submit. Browser login
  is currently required before this final UI step can be performed.
- Post-upload simulator testing found that the first search-position fix kept
  the logical month but produced an unnatural animation: the month item height
  was recomputed on every frame as the inline search panel resized the calendar
  viewport. Vertical month items now retain their stable height while the
  search panel opens or closes; only the visible viewport is pushed/resized.
  This removes per-frame calendar compression and controller correction while
  preserving the exact month and fractional scroll offset. Static analysis and
  all 48 widget tests pass, and the updated build is installed on the iPhone 17
  simulator without launching it.
- Do not submit the already uploaded App Store Connect `3.0.0 (3.0.0)` builds:
  they were generated before this post-upload animation correction. After the
  user confirms the simulator behavior, increment the Apple build/version
  according to the current version policy, rebuild both Apple artifacts, upload
  those newer builds, and select only the newer builds for review.
## 2026-08-02 검색 전환 및 상하 월 스크롤 성능 수정

- 검색 버튼 전환에서 사용하던 `AnimatedSize`가 달력 전체 높이를 매 프레임
  변경해 월 그리드를 반복 레이아웃하던 구조를 제거했다.
- 검색 패널은 별도 레이어에서 펼쳐지고, 달력은 `RepaintBoundary`를 유지한 채
  합성 단계의 `Transform`으로만 밀리도록 변경했다.
- 검색 결과로 패널 높이가 달라질 때도 달력 자체를 재레이아웃하지 않고 이동
  거리만 짧게 보간한다.
- 상하 월 스크롤 중 달 경계를 지날 때마다 `visibleMonthProvider`를 갱신하던
  동작을 제거했다. 스크롤 중에는 내부 페이지 번호만 추적하고 스크롤 종료 시
  최종 월을 한 번만 전역 상태에 반영한다.
- iOS `Info.plist`의 `CADisableMinimumFrameDurationOnPhone = true`가 유지되어
  실제 ProMotion 기기에서는 시스템이 허용하는 동적 주사율 범위를 사용한다.
  Simulator와 debug 빌드만으로 120Hz 실측을 확정할 수는 없다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub test/widget_test.dart` 48개 통과
  - `./tool/flutter.sh test --no-pub` 전체 142개 통과
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532` debug 빌드 성공
  - 기존 시뮬레이터 앱에 업데이트 설치 완료, 자동 실행하지 않음
- 기존 App Store Connect의 `3.0.0 (3.0.0)` 업로드 빌드는 이 수정 전 산출물이다.
  사용자가 실사용 검증을 마치기 전에는 해당 빌드를 심사 제출하지 않는다.

## 2026-08-02 App Store 제출 후보 3.0.1

- 기존 App Store Connect의 `3.0.0 (3.0.0)`과 중복되지 않도록 최신 검색 및
  상하 월 스크롤 성능 수정본을 Apple 제출 산출물 `3.0.1 (3.0.1)`로 생성했다.
- 저장소의 공통 `pubspec.yaml` 버전은 변경하지 않고 Apple 제출 빌드 인자에만
  `3.0.1`을 적용했다.
- iOS의 고정 `CFBundleVersion`을 `$(FLUTTER_BUILD_NUMBER)`로 변경해 이후 제출
  빌드 인자가 메인 앱에 반영되도록 했다.
- macOS `MACOS_BUILD_NUMBER`도 `$(FLUTTER_BUILD_NUMBER)`를 사용하도록 변경했다.
- iOS/macOS Release 위젯 타깃은 이번 제출 앱과 일치하도록 `3.0.1`을 사용한다.
- iOS Transporter 파일:
  - `dist/transporter-ios-3.0.1/Daily-iOS-AppStore-3.0.1-build-3.0.1.ipa`
  - 앱 ID `com.littlebit0.daily`, 위젯 ID `com.littlebit0.daily.widgets`
  - 앱/위젯 모두 버전 및 빌드 `3.0.1`
  - SHA-256 `8bd2f754476101173c3873b6dd664bd0299c880535c41e7680633b16f68a858e`
- macOS Transporter 파일:
  - `dist/transporter-macos-3.0.1/Daily-macOS-AppStore-3.0.1-build-3.0.1.pkg`
  - 앱 ID `com.littlebit0.daily`, 위젯 ID `com.littlebit0.daily.widgets`
  - 앱/위젯 모두 버전 및 빌드 `3.0.1`
  - Installer 인증서 서명과 앱 `codesign --verify --deep --strict` 통과
  - SHA-256 `e703b7ed98a0715324bf2c06e79e6c23d3e7a666c6860c49115a9cd45f77e450`
- macOS export에서 Xcode 자동 버전 관리가 App Store Connect 코드 서명 요청을
  빈 결과로 반환해 첫 시도가 실패했다. `manageAppVersionAndBuildNumber=false`로
  로컬 검증 버전을 유지한 재시도는 정상 성공했다.
- 심사 메모는 `docs/APP_REVIEW_NOTES_3.0.1.md`에 iOS/macOS별로 작성했다.
# 2026-08-03 App Store 3.0.1 Release Baseline

- The current shared release version is `3.0.1`; Apple app version and build
  metadata are both `3.0.1 (3.0.1)`.
- Current Apple identifiers are:
  - iOS/macOS app: `com.littlebit0.daily`
  - iOS/macOS widget extension: `com.littlebit0.daily.widgets`
- The iOS and macOS 3.0.1 binaries were uploaded through Transporter and their
  App Store metadata was updated. At the last confirmed App Store Connect
  state, iOS was still preparing for submission and macOS was ready for review;
  final review submission must not be assumed complete without rechecking App
  Store Connect.
- Local App Store submission artifacts are:
  - `dist/transporter-ios-3.0.1/Daily-iOS-AppStore-3.0.1-build-3.0.1.ipa`
  - `dist/transporter-macos-3.0.1/Daily-macOS-AppStore-3.0.1-build-3.0.1.pkg`
- Current release documentation is centered on:
  - `docs/RELEASE_NOTES_3.0.1.md`
  - `docs/APP_STORE_WHATS_NEW_3.0.1.md`
  - `docs/APP_REVIEW_NOTES_3.0.1.md`
  - `docs/STORE_SUBMISSION.md`
- Private/sensitive-event behavior was removed from the current product model,
  database, settings, and UI. Historical notes remain in this file as dated
  development history and must not be treated as current behavior.
- iOS/macOS release verification has been performed locally. Android and
  Windows remain shared-source targets but still require platform-specific
  build and manual verification before their 3.0.1 artifacts are published.

## 2026-08-12 다국어 지원 작업

- 지원 언어를 한국어, 영어, 일본어, 중국어 번체로 추가했다.
- 기본값은 시스템 언어를 따르며, 미지원 시스템 언어는 영어로 표시한다.
- 설정 > 화면 > 언어에서 시스템 설정, 한국어, English, 日本語, 繁體中文을
  기기별로 직접 선택할 수 있다. 언어 선택은 계정 동기화로 다른 기기에
  강제 적용되지 않는다.
- 온보딩, 캘린더, 검색, 일정 추가/상세, 주요 설정, 알림과 Apple 위젯의 핵심
  문구 및 날짜 형식이 선택 언어를 따른다.
- 일정 빠른 추가·추가·수정 화면의 반복 주기 선택값, 반복 간격, 종료일 및
  반복 횟수도 선택 언어를 따르도록 후속 보정했다.
- 상하 월 스크롤 경계와 연 화면 미니 달력의 월명을 로케일 형식으로 바꾸고,
  iOS 좌우 연월 제목의 긴 영어 월명은 잘리지 않도록 가변 폭과 자동 축소를
  적용했다. 한국 공휴일 명칭은 저장값을 유지하면서 화면·검색·알림·Apple
  위젯에서 선택 언어로 표시한다.
- iOS는 네 언어의 캘린더, Face ID, AlarmKit 권한 설명을 앱 번들에 포함한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 현지화, 설정 저장, Apple 위젯, 기존 widget 테스트 총 56개 통과
  - iOS Simulator debug 빌드 성공 및 네 개 `InfoPlist.strings` 포함 확인
  - macOS debug 빌드 성공
- Android와 Windows는 공유 Flutter UI가 적용되지만 각 실제 OS에서 언어 변경,
  긴 번역 문구 레이아웃, 알림 문구를 수동 검증해야 한다.

### 2026-08-13 iOS 캘린더 가져오기 번역 보정

- 설정의 `Apple 캘린더 또는 Google 캘린더에서 가져옵니다.` 세부 설명이
  번역 함수를 거치지 않던 누락을 수정했다.
- iOS 네이티브 캘린더 권한 거절과 캘린더 선택 누락 오류를 오류 코드로
  분기해 한국어, 영어, 일본어, 중국어 번체로 표시한다.
- Google 캘린더 가져오기 과정의 로그인 필요 및 응답 형식 오류도 현재 앱
  언어를 따르도록 보정했다.

### 2026-08-13 계정 설정 및 캘린더 요일 번역 보정

- macOS 일본어 계정 설정 GUI를 직접 확인해 Apple/Google 연결 상태, Drive
  설명, 백업 버튼, 동기화 상태 및 Daily 계정 탈퇴에 남아 있던 한국어를
  번역했다. 공유 Flutter 화면이므로 iOS에도 동일하게 적용된다.
- 주간 달력의 `일정 없음`과 월간·주간·연간 미니 달력의 요일을 현재 언어로
  표시한다.
- 캘린더 보기의 주/월/일 명칭을 요일 번역과 분리했다. 영어에서는
  `Week / Month / Day`로 표시하고 일요일은 계속 `Sun`으로 표시한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 현지화, 월간 그리드, 기존 widget 테스트 68개 통과
  - macOS `Daily Test.app` 업데이트 설치 후 일본어 계정 설정 GUI 확인 완료
  - iPhone 17 Simulator 업데이트 설치 완료, 설치 전후 SQLite SHA-256 동일
- 빠른 보기 월 요약의 일정, D-day, 공휴일 개수 문구도 네 언어로 표시하도록
  후속 보정했다.
- iOS 하단 좌측 캘린더 보기 슬라이드는 고정 폭을 제거하고 번역된
  `Week / Month / Day` 등의 실제 텍스트 폭에 따라 자동 확장한다. 중앙
  슬라이드의 현재 폭과 화면 여유를 함께 계산해 두 슬라이드가 겹치지 않는다.

### 2026-08-13 주간·일간 스케줄 표시 방식

- 설정 > 달력에 `주간·일간 표시 방식` 목록/스케줄 2단 캡슐을
  추가했다. 기본값은 기존 동작을 유지하는 `목록`이다.
- 스케줄 모드는 주간·일간 날짜 이동을 기존 가로 `PageView`로만
  처리하고, 페이지 내부의 24시간 축만 세로 스크롤한다.
- 시간 일정은 시작·종료 시각에 맞춰 블록으로 표시하고, 중복 시간대의
  일정은 여러 열로 배치한다. 현재 시간 표시선도 제공한다.
- 종일 일정은 주간·일간 스케줄 하단 오른쪽의 원형 버튼으로 표시/
  숨김을 즉시 전환한다. 표시 상태는 주간과 일간 화면이 공유한다.
- 표시 방식은 로컬 설정과 Google Drive 설정 동기화에 포함된다.
  기존 원격 설정 파일에 해당 키가 없으면 현재 기기의 선택을 보존한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 설정 저장·구버전 동기 호환·명시적 원격 설정 복원 테스트 통과
  - 시간축 세로 스크롤, 가로 주 이동, 종일 일정 토글 widget 테스트 통과

### 2026-08-13 Siri 및 App Intents 지원

- iOS 16 이상과 macOS 13 이상에서 Apple App Intents 기반 Siri/단축어
  기능을 추가했다. iOS와 macOS는 같은 `apple_siri/DailySiriIntents.swift`
  구현을 사용한다.
- 허용한 작업:
  - 일정 한 건 추가
  - 오늘, 내일, 지정 날짜, 다음 일정 조회
  - 제목/메모/장소 텍스트 검색
  - 정확한 제목으로 일정 한 건 수정
  - 정확한 제목으로 일정 한 건 삭제. 삭제는 기기 인증과 Apple 표준 실행
    확인을 모두 거친다.
  - D-day 일정 조회
  - Daily 캘린더 열기
- 계정 탈퇴, 전체 데이터 초기화, Apple/Google 연결 해제, Google Drive
  백업 삭제, 일괄 수정/삭제, 동기화 충돌 처리는 App Intent로 제공하지 않는다.
  범용 LLM 명령을 Siri에 연결하는 우회 경로도 만들지 않았다.
- 인증 정책:
  - 일정 조회와 추가는 Siri 개인 인증이 필요하다.
  - 일정 수정과 삭제는 로컬 기기 인증이 반드시 필요하다.
  - 앱 열기만 인증 없이 허용한다.
- 반복 일정 조회는 원본 레코드가 아니라 일/주/월/연 반복 간격, 종료일,
  횟수, 제외 날짜를 반영한 실제 발생 일정으로 응답한다.
- Siri가 앱 밖에서 SQLite를 변경한 뒤 Daily가 복귀하면 Drift 일정 범위
  스트림을 다시 만들어 화면에 변경 사항이 반영되도록 했다. Siri 변경
  레코드는 기존 v2 동기화가 업로드할 수 있도록 `pending` 또는
  `pending_delete` 상태로 저장한다.
- 설정 > Siri 작업 기록에서 실행 기록을 날짜별로 조회할 수 있다.
  - 기록 항목: 실행 시각, 작업 종류, 확정된 일정 제목/검색어, 성공/실패,
    결과
  - 원문 음성, 전체 Siri 대화, 계정 토큰은 저장하지 않는다.
  - 기록은 Apple App Group의 `daily-siri-action-logs.json`에 최대 1,000건
    저장하며 사용자가 전체 삭제할 수 있다.
  - 메뉴는 iOS와 macOS에서만 표시한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 162개 통과
  - iOS Simulator와 macOS 네이티브 Xcode debug 컴파일 통과
  - App Intents 메타데이터에서 9개 Intent와 인증 정책 추출 확인
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`에 업데이트
    설치 완료, 자동 실행하지 않음
  - `/Applications/Daily Test.app` 업데이트 설치 및 코드 서명 검증 완료,
    자동 실행하지 않음

### 2026-08-13 Siri 인식 정밀화

- 최초에는 `시그널` 단축어에서 `Daily Signal(매번 묻기)`를 사용했으나,
  후속 발화를 Siri 전역 라우터가 다시 해석하면서 웹 검색이나 Apple 캘린더로
  빠질 수 있음을 실제 사용에서 확인했다.
- 최종 `시그널` 단축어는 `텍스트 받아쓰기 -> Daily Signal` 두 단계다.
  받아쓰기 단계가 후속 발화를 단축어 안에서 먼저 캡처하고, Daily Signal에는
  `받아쓰기한 텍스트`를 전달한다. 따라서 후속 문장을 Siri 전역 검색에 다시
  넘기지 않는다.
- Daily Signal은 전달된 문장을 허용 목록으로만 분류한다. 오늘, 내일, 지정
  날짜, 다음 일정, 검색, D-day, 추가, 수정, 삭제 외의 명령은 실행하거나 다른
  앱으로 보내지 않고 지원 작업을 다시 묻는다. 수정·삭제·추가 키워드를 조회
  키워드보다 먼저 판정해 `내일 일정 삭제`를 단순 내일 조회로 오해하지 않는다.
- `DailySiriAction` AppEnum에 오늘, 내일, 지정 날짜, 다음 일정, 검색, D-day,
  추가, 수정, 삭제의 9개 작업과 한국어 동의어를 등록했다. `내일 일정 알려줘`,
  `내일 스케줄`, `내일 일정 확인` 같은 표현은 일반 웹 검색 문자열이 아니라
  Daily 작업 후보로 전달된다.
- 일정 수정과 삭제는 자유 텍스트 제목 대신 `DailyEventEntity`를 사용한다.
  Siri/단축어는 현재 SQLite에서 검색한 실제 일정 후보를 제시하며, 삭제의
  기기 인증과 실행 확인 정책은 그대로 유지한다.
- 오늘, 내일, 지정 날짜, 다음 일정, 검색, 추가, 수정, 삭제, D-day, 캘린더
  열기의 직접 App Shortcut 10개를 등록했다. 각 Shortcut은 앱 이름을 포함한
  한국어 및 영어 호출 예시를 제공한다.
- iOS와 macOS의 Siri 앱 이름을 `Daily`로 명시하고 `데일리`, `데일리 테스트`,
  `데일리 캘린더`를 대체 앱 이름으로 등록했다. `시그널`은 사용자 단축어와
  앱 이름이 충돌하지 않도록 대체 앱 이름에는 넣지 않았다.
- 지원 범위:
  - 직접 App Shortcut은 iOS 16 이상, macOS 13 이상에서 제공한다.
  - `시그널`의 제한 명령 분류와 구조화된 작업 선택은 AppEnum API를 사용할 수
    있는 iOS 17 이상, macOS 14 이상에서 제공한다.
  - Apple Calendar App Schema는 현재 설치된 Xcode 26.6 / iOS·macOS SDK
    26.5에 타입이 없고 iOS 27/macOS 27 SDK가 필요하므로 이번 빌드에는
    추측 구현을 넣지 않았다. Xcode 27 도입 후 기존 AppEntity를 Calendar App
    Schema 엔티티와 연결하는 후속 검증이 필요하다.
- 검증:
  - iOS Simulator debug 빌드 성공
  - macOS debug 빌드 성공 및 `/Users/kimhwi/Applications/Daily Test.app` 실행
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532` 업데이트 설치
  - App Intents 메타데이터에서 11개 Intent, `DailyEventEntity`, 9개
    `DailySiriAction` 값과 동의어, 10개 App Shortcut 추출 확인
  - macOS 단축어 앱에서 `시그널`이 `텍스트 받아쓰기 -> Daily Signal` 순서이고
    Signal phrase가 `받아쓰기한 텍스트`에 연결된 것을 재확인
  - 실제 iPhone은 검증 시점에 Mac에서 오프라인 상태였다. 새 App Intent가
    포함된 테스트 앱을 실제 iPhone에 설치하기 전에는 이 변경을 실기기에서
    검증할 수 없다.

### 2026-08-14 Apple Intelligence 생성형 명령 해석

- iOS/macOS 26 이상에서 Apple Intelligence의 온디바이스 Foundation Models를
  사용해 `시그널` 후속 문장을 구조화한다.
  - 한국어, 영어, 일본어, 중국어 번체 문장에서 작업 종류, 대상 일정 표현,
    검색어, 변경할 새 제목을 추출한다.
  - 지원 작업은 오늘/내일/지정 날짜/다음 일정/검색/D-day/추가/수정/삭제로
    제한하며, 관련 없거나 애매한 문장은 `unknown`으로 처리한다.
  - 일정·제목·장소를 모델이 임의로 만들지 않도록 구조화 출력과 명시적
    지침을 사용한다.
- 안전성과 하위 호환성:
  - 기존 키워드 판별기는 제거하지 않았다. Apple Intelligence 미지원 기기,
    기능 꺼짐, 모델 준비 중, 현재 언어 미지원, 생성 실패 시 기존 판별기로
    즉시 복귀한다.
  - 명시적인 추가/수정/삭제 키워드는 생성형 모델보다 먼저 판정한다.
  - 생성형 해석으로 수정·삭제가 선택돼도 기존 기기 인증, 실제 일정 엔티티
    확인, 삭제 확인 창을 그대로 거치며 모델이 임의 실행하지 않는다.
- iOS 18/macOS 15 이상에서는 `DailyEventEntity`를 Core Spotlight에
  `IndexedEntity`로 등록한다.
  - 제목, 메모, 장소, 시작/종료 시각, 종일 여부를 인덱싱해 Siri와 Apple
    Intelligence가 실제 Daily 일정 엔티티를 의미 기반으로 찾을 수 있게 했다.
  - 앱 시작, Flutter 일정/위젯 스냅샷 갱신, Siri 일정 추가·수정·삭제 뒤에
    500ms 병합 지연을 두고 전용 Spotlight 인덱스를 갱신한다.
- 현재 Xcode 26.6 / SDK 26.5에는 Calendar App Schema 타입이 없으므로 추측
  구현은 넣지 않았다. Xcode 27 도입 후 Apple Calendar App Schema 연결을
  별도로 검증해야 한다.
- 검증:
  - iPhone 17 Simulator 대상 iOS debug Xcode 빌드 통과
  - macOS debug Xcode 빌드 통과
  - 두 플랫폼 모두 App Intents 메타데이터 추출 단계 통과
  - 시뮬레이터는 Apple Intelligence 모델을 제공하지 않으므로 실제 생성형
    해석 품질은 Apple Intelligence가 활성화된 지원 실기기에서 확인해야 한다.

### 2026-08-14 Siri/단축어 항상 허용 및 테스트 앱 서명 수정

- macOS 테스트 앱이 `CODE_SIGNING_ALLOWED=NO` 빌드 뒤 ad-hoc 서명된 상태로
  설치되어 App Intents의 앱 ID와 권한을 시스템이 정상적으로 신뢰하지 못하던
  원인을 확인했다.
- macOS `Daily Test.app`을 Apple Development 인증서와 Team
  `A6Y73X2ZLS`로 다시 빌드·설치했다. 설치본에는 다음 entitlement가 유지된다.
  - application identifier `A6Y73X2ZLS.com.littlebit0.daily.test`
  - App Group `A6Y73X2ZLS.com.littlebit0.daily.widgets`
  - Sign in with Apple, App Sandbox, 네트워크 권한
- 앞으로 `CODE_SIGNING_ALLOWED=NO` 빌드는 컴파일 검증에만 사용할 수 있으며,
  macOS 테스트 앱 설치본을 해당 산출물로 교체하거나 사후 ad-hoc 재서명하면
  안 된다.
- 통합 `Daily Signal` Intent의 전체 인증 정책을
  `requiresLocalDeviceAuthentication`에서 `requiresAuthentication`으로
  조정했다. 조회·검색·추가는 사용자가 Siri/단축어에서 선택한 `항상 허용`을
  존중한다.
- 일정 수정·삭제는 통합 Intent 내부에서 실행 직전에 `LAContext`의
  `deviceOwnerAuthentication`을 별도로 요구한다. 따라서 파괴적 변경의
  Touch ID/시스템 암호 보호는 유지된다.
- iOS Simulator와 macOS Apple Development 서명 빌드가 모두 통과했고,
  iPhone 17 Simulator 및 `/Users/kimhwi/Applications/Daily Test.app`에
  업데이트 설치했다. App Intents 재등록을 위해 두 앱을 한 번 실행한 뒤
  종료했다.
- 기존 권한 캐시는 전역 초기화하지 않았다. 새 서명 설치본의 첫 실행에서
  권한을 한 번 다시 물으면 `항상 허용`을 선택한 뒤 이후 반복 여부를 실기기에서
  확인해야 한다.
- 같은 bundle identifier의 임시 Xcode 빌드
  `/private/tmp/daily-siri-test-derived/.../Daily Test.app`이 Launch Services에
  함께 등록되면, 단축어 동작 목록에는 `Daily Signal`이 보여도 추가·실행 시
  `알 수 없는 동작`으로 바뀐다. 임시 DerivedData를 clean하고 등록을 해제한 뒤
  `/Users/kimhwi/Applications/Daily Test.app`만 다시 등록해 해결했다.
- 기존 `시그널` 단축어의 끊어진 블록도 재등록 뒤 자동 복구되었다. 현재 구성은
  `텍스트 받아쓰기 -> 받아쓰기한 텍스트를 Daily에서 실행`이며, 단축어 편집
  화면에서 더 이상 `이 버전의 단축어 앱에서 이 동작을 찾을 수 없습니다`가
  표시되지 않는다.

### 2026-08-14 Siri 일정 즉시 반영 및 생성형 후속 질문

- Siri/App Intent가 별도 SQLite 연결로 일정을 추가·수정·삭제하면 Drift의
  기존 watch 쿼리가 외부 변경을 감지하지 못해 월간, 주간·일간, 오른쪽 하루
  패널이 서로 다른 데이터를 잠시 표시하던 원인을 수정했다.
- Siri 저장 직후 Darwin notification
  `com.littlebit0.daily.siri.events-changed`를 전송한다. iOS/macOS Runner가 이를
  수신해 Flutter `daily/siri_event_changes` 채널로 즉시 전달한다.
- Flutter는 변경 신호 하나로 `eventsInRangeProvider` family 전체를 무효화한다.
  이에 따라 현재 생성된 월간·주간·일간·하루 패널의 범위 스트림이 같은 시점에
  다시 조회된다. 위젯 스냅샷도 갱신하고 Google Drive에 연결된 경우 pending
  Siri 변경을 백업 큐로 전달한다.
- `Daily Signal`은 명시적인 추가·수정·삭제 문장도 Apple Intelligence 구조화
  해석을 실행한다. 이전에는 규칙 기반으로 mutation을 먼저 찾으면 생성형
  해석을 건너뛰어 제목 외 일정 필드를 주입할 수 없었다.
- 생성형 구조화 결과에 다음 필드를 추가했다.
  - 새 일정 제목, 시작/종료, 종일 여부, 장소, 메모
  - 수정 대상 표현, 새 제목, 새 시작/종료
- 모델에는 현재 시각과 시간대를 제공해 오늘/내일 같은 상대 표현만 계산하게
  하고, 사용자가 말하지 않은 제목·날짜·시간·장소·메모는 만들지 못하도록
  지시했다. ISO 8601 형식으로 받은 시각만 실제 App Intent 입력으로 사용한다.
- 일정 추가에서 제목이 빠지면 제목만, 완전한 시작 날짜·시간이 빠지면 시작
  정보만 Siri가 이어서 질문한다. 종료는 선택 정보라 생략 시 기존 정책대로
  시간 일정은 1시간, 종일 일정은 1일로 설정한다. 장소와 메모도 말한 경우에만
  주입한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub test/widget_test.dart` 52개 통과
  - macOS Debug 네이티브 빌드 및 App Intents 메타데이터 추출 통과
  - iPhone 17 Simulator 대상 iOS Debug 네이티브 빌드 및 App Intents
    메타데이터 추출 통과
  - 임시 macOS/iOS DerivedData 산출물 clean 완료. 기존 설치 앱은 교체하거나
    실행하지 않았다.
- 실기기에서는 Apple Intelligence가 활성화된 상태에서 다음을 수동 확인해야
  한다.
  - `내일 오후 3시에 병원 일정 추가`가 제목·시작을 한 번에 주입하는지
  - `내일 병원 일정 추가`처럼 시간이 빠진 문장에서 시작 시각만 다시 묻는지
  - 생성 직후 월간, 주간·일간, 하루 패널에 같은 일정이 동시에 나타나는지
- 테스트 설치 업데이트:
  - `/Users/kimhwi/Applications/Daily Test.app`을 Apple Development 서명
    빌드로 업데이트하고 코드 서명·App Group·Apple 로그인 entitlement를
    검증했다.
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`의 기존
    `com.littlebit0.daily` 위에 업데이트 설치했다. 설치 전후 `daily.sqlite`
    SHA-256이 동일해 기존 일정 데이터가 유지됐다.
  - 두 앱 모두 자동 실행하지 않았고 임시 DerivedData 앱 산출물을 clean했다.

### 2026-08-14 Siri 한국어 시간대 해석 및 사용 기록 상세 보기

- `오늘 일정 추가 헬스장 9~11시`가 `18~20시`로 저장되던 원인은 생성형
  해석 결과의 UTC 시각을 한국 현지 시각처럼 사용하면서 9시간이 더해지는
  경로였다.
- Siri 발화에 포함된 한국어 상대 날짜와 시간 범위를 현지 달력 기준으로 먼저
  확정하는 파서를 추가했다.
  - `오늘`, `내일`, `모레`
  - `9~11시`, `오후 1시부터 3시`, 단일 `9시`
  - 명시적 App Intent 입력, 현지 발화 파서, Apple Intelligence 결과 순으로
    우선 적용한다.
- Apple Intelligence에 전달하는 현재 시각도 기기 현지 시간대와 시간대
  식별자를 포함하도록 수정했다.
- 설정의 Siri 사용 기록은 각 항목을 탭하면 시스템 하단 시트에서 동작, 상태,
  실행 시각, 요약, 결과와 일정 제목·시작·종료·종일·장소·메모를 확인할 수
  있다.
- 원문 음성이나 전체 대화는 새로 저장하지 않는다. 일정 작업에서 생성된
  구조화 필드만 기록하며 기존 상세 정보가 없는 기록도 계속 열 수 있다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - Siri 기록 상세 화면 및 전체 위젯 테스트 54개 통과
  - iOS Simulator와 macOS 제품 빌드 통과
  - 정확한 한국어 예문에 대한 iOS/macOS XCTest를 추가했다. 다만 기존 Xcode
    테스트 타깃의 `TEST_HOST` 및 Swift Package 리소스 번들 중복 복사 문제로
    네이티브 XCTest 실행 자체는 완료하지 못했으며, 제품 빌드에서 해당 Swift
    코드는 정상 컴파일됐다.
- 설치:
  - `/Users/kimhwi/Applications/Daily Test.app`을 Apple Development 서명
    빌드로 업데이트했다.
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`에 업데이트
    설치했고 설치 전후 `daily.sqlite` SHA-256이 동일함을 확인했다.
  - 두 앱 모두 자동 실행하지 않았다.

### 2026-08-21 GitHub 이슈 #42 일정 날짜 이동 및 날짜별 수동 순서

- 월간 일정 플래그를 길게 누른 뒤 다른 날짜 셀로 드래그하면 일정 날짜가
  변경된다. 읽기 전용, 시스템, 공휴일 일정은 이동할 수 없다.
- 시간 일정은 기존 시작 시각과 기간을 유지하고, 종일·연속 일정은 배타적
  종료일을 포함한 기존 일수만큼 그대로 이동한다.
- 반복 일정은 드롭 직후 `이 일정만`, `이후 일정`, `전체 반복` 중 적용 범위를
  먼저 선택한다. 범위를 선택하지 않으면 원본 반복 일정을 변경하지 않는다.
- 같은 날짜 안에서 위아래 위치로 드롭하면 전역 분류/시간 우선순위와 별개인
  날짜별 수동 순서를 저장한다. 반복 발생 일정은 결정적인 occurrence ID로
  구분한다.
- 날짜별 순서는 이벤트 키 목록, 수정 시각, 기기 ID로 저장한다. Google Drive
  설정 복원 시 날짜별로 더 최신인 항목을 선택하고, 같은 시각이면 기기 ID로
  결정해 다른 날짜의 수동 순서를 덮어쓰지 않는다.
- 일정 이동은 기존 EventCommandService를 사용하므로 알림, 알람, Apple 위젯,
  이벤트별 Google Drive 백업을 즉시 갱신한다. 순서 설정도 대기 설정 백업을
  별도로 예약한다.
- 기존 날짜 범위 추가 제스처는 일정 드래그가 시작되면 즉시 취소되며, 드롭
  가능한 날짜 셀만 시각적으로 표시한다.
- 검증:
  - 시간 일정 시각/기간 및 종일 연속일정 기간 보존
  - 날짜별 수동 순서와 반복 occurrence 순서
  - 로컬 설정 재시작 보존과 기기 간 최신값 병합
  - 실제 길게 누르기 후 다른 날짜 드롭
  - Google Drive 설정 파일 직렬화 및 백업
  - 관련 테스트 55개와 `./tool/flutter.sh analyze --no-pub` 통과

### 2026-08-21 GitHub 이슈 #41 화이트 모드 노란색 가독성

- 일정과 분류에 저장되는 원본 색상 값은 변경하지 않는다. 동기화와 사용자 지정
  색상도 기존 값 그대로 유지한다.
- 밝은 테마에서 노란색 계열의 일정 전경색만 실제 배경과 WCAG 4.5:1 이상의
  대비가 되도록 계산해 어둡게 표시한다.
  - 월간, 주간, 일간 및 스케줄 일정
  - 일정 상세 목록과 상세 시트
  - 검색 결과의 분류 아이콘
  - Apple D-day 위젯 숫자
- 일정 배경은 원본 분류색을 유지하므로 색상 정체성은 그대로이며, 다크 모드와
  노란색이 아닌 분류색은 보정하지 않는다.
- 빠른 보기는 분류색을 전경으로 직접 쓰지 않고 테마 본문색을 사용하므로 별도
  색상 변경 없이 기존 고대비 표시를 유지한다.
- 검증:
  - 밝은 테마의 기본 노란색과 사용자 지정 노란색 대비 4.5:1 이상
  - 비노란색 및 다크 모드 색상 불변
  - 월간/스케줄 관련 테스트 포함 총 22개 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - iOS Simulator Debug 빌드 및 Apple 위젯 Swift 컴파일 통과

### 2026-08-21 GitHub 이슈 #37 공휴일 분류 색상과 날짜 배경

- 잠긴 기본 분류인 `공휴일`은 이름과 삭제는 계속 막지만 색상은 수정할 수
  있도록 변경했다.
- 공휴일 분류의 사용자 지정 색상은 로컬 설정과 Google Drive v2 설정 파일에
  보존되며, 이전 백업에 새 필드가 없어도 기존 로컬 설정을 유지한다.
- 한국 공휴일 동적 일정은 정적 기본 색상이 아니라 현재 설정의 공휴일 분류와
  색상을 사용한다. 색상 변경 뒤 이벤트 자체를 다시 저장할 필요가 없다.
- 설정에 `공휴일 날짜 배경` ON/OFF를 추가했다. 활성화하면 월간 날짜 셀,
  주간 날짜 패널, 일간 날짜 헤더, 주·일 스케줄 헤더에 공휴일 분류 색상을
  저채도 배경으로 표시하며, 비활성화하면 배경만 숨긴다.
- 영어, 일본어, 중국어 번체 설정 문구를 함께 추가했다.
- 검증:
  - 공휴일 색상 생성, 설정 영속화, 월간 및 스케줄 배경, Google Drive 설정
    복원 관련 테스트 46개 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `git diff --check` 통과

### 2026-08-21 GitHub 이슈 #38 일정 제목 정렬

- 설정의 달력 섹션에 `일정 제목 정렬` 2단 캡슐 선택을 추가했다.
  - `기본`: 기존 시작 방향 정렬
  - `가운데`: 일정 제목 가운데 정렬
- 월간 연속 일정 바, 주간 목록 일정, 일간 일정 목록, 주·일 스케줄의 종일 및
  시간 일정, 빠른 보기 항목에 같은 선택값을 즉시 적용한다.
- 정렬만 변경하고 기존 최대 줄 수, 말줄임, 일정 바와 카드의 높이 계산은
  변경하지 않았다.
- 선택값은 로컬 설정과 Google Drive v2 설정 파일에 저장한다. 이전 원격
  설정에 필드가 없으면 현재 기기의 값 또는 기존 기본 정렬을 유지한다.
- 영어, 일본어, 중국어 번체 설정 문구를 추가했다.
- 검증:
  - 설정 영속화, 이전 원격 설정 호환, 월간 높이 유지, 스케줄 종일 일정 정렬
    관련 테스트 47개 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `git diff --check` 통과

### 2026-08-21 GitHub 이슈 #39 분류 순서와 일정 정렬 우선순위

- 분류 목록을 `ReorderableListView`로 변경하고 각 항목 맨 왼쪽에 6점 드래그
  핸들을 추가했다. 핸들을 길게 눌러야 재정렬되며 표시 체크, 수정, 삭제 동작은
  기존대로 유지한다.
- `일정 정렬 우선순위`를 `분류 우선 / 시간 우선` 2단 캡슐로 추가했다.
  - 분류 우선: 저장된 분류 순서, 시작 시각 순
  - 시간 우선: 시작 시각, 저장된 분류 순
  - 종료 시각, 제목, ID를 안정적인 보조 기준으로 사용한다.
- 월간 일정 레인, 주간·일간 목록, 빠른 보기, 스케줄의 종일 일정과 겹치는
  시간 일정 레인에 공통 정렬 규칙을 적용했다.
- 분류 순서 또는 정렬 기준 변경 시 월간 레인 캐시를 즉시 다시 계산한다.
- 분류 추가·수정·삭제와 캘린더 가져오기는 기존 분류 순서를 보존하며 새 분류만
  뒤에 추가한다.
- 분류 배열 순서와 정렬 기준은 로컬 설정 및 Google Drive v2 설정 파일에
  저장한다. 이전 원격 설정에 기준 필드가 없으면 현재 기기 값을 유지한다.
- 영어, 일본어, 중국어 번체 설정 및 드래그 도움말을 추가했다.
- 검증:
  - 공통 comparator, 설정 영속화, 원격 설정 호환, 월간 레인 즉시 변경,
    스케줄 겹침 레인 관련 테스트 53개 통과
  - 분류 드래그 핸들과 우선순위 설정 위젯 테스트 통과
  - `./tool/flutter.sh analyze --no-pub` 및 `git diff --check` 통과

### 2026-08-21 수동 복원 전 자동 백업 차단 (#50)

- 설정의 `복원`은 Google Drive 원격 데이터를 로컬로 내려받는 복원 전용
  작업으로 유지한다. 복원 직전 백업을 요구하거나 자동으로 실행하지 않는다.
- 복원 버튼을 누르기 전에 예약돼 있던 변경 백업 타이머를 취소하고 수동
  복원을 대기열 최우선으로 처리한다.
- 복원 도중 발생한 로컬 변경은 업로드하지 않고 대기 상태로 유지한다.
  복원이 성공한 경우에만 복원 완료 후 변경 백업을 다시 예약한다.
- 인증, 네트워크 또는 복원 처리 실패 시 보류된 변경을 즉시 업로드하지 않아
  원격 백업을 변경하지 않는다.
- macOS/iOS를 포함한 공유 `GoogleDriveSyncService` 동작이다. 각 플랫폼에서
  복원 직전 대기 변경이 있는 실사용 흐름은 별도로 확인해야 한다.
- 검증:
  - Google Drive 동기화 서비스 테스트 29개 통과
  - 설정의 백업/복원 분리 위젯 테스트 통과
  - `./tool/flutter.sh analyze --no-pub` 통과

### 2026-08-21 반복 일정 종료일 포함 처리 (#40)

- 반복 종료일은 시각이 아니라 로컬 달력 날짜를 기준으로 포함 비교한다.
  날짜 선택기로 저장한 종료일 `00:00`과 시간 일정의 시작 시각을 직접
  비교해 종료일 당일이 누락되던 문제를 수정했다.
- 시간 일정과 종일 일정에 같은 포함 규칙을 적용하며, 종료일 이후 발생분은
  생성하지 않는다.
- 매일, 매주, 매월, 매년 반복의 종료일 일치 발생분을 회귀 테스트로
  고정했다. 기존 반복 일정도 같은 `RecurrenceExpander`를 사용하므로 수정 후
  조회 시 동일하게 반영된다.
- 검증:
  - 반복 일정 확장 테스트 6개 통과
  - 일정 편집기 및 저장소 관련 테스트 9개 통과

### 2026-08-21 macOS 목록 모드 마우스 연속 이동 안정화 (#44)

- macOS 목록 모드의 월·주·일 페이지에서 일반 마우스 휠과 트랙패드 입력을
  분리했다.
- 일반 마우스의 각 좌우 스크롤 틱은 애니메이션 중인 현재 표시 페이지가
  아니라 마지막 목표 페이지를 기준으로 한 단계씩 누적한다. 같은 방향의
  연속 입력에서 목표가 뒤로 되돌아가거나 입력이 280ms 제한으로 누락되지
  않는다.
- 트랙패드는 기존 축 임계값, 관성 입력 제한과 페이지 제스처를 유지한다.
- 툴바·버튼으로 외부 이동이 시작되면 대기 중인 마우스 목표를 초기화해 서로
  다른 이동 경로가 섞이지 않게 했다.
- 검증:
  - macOS 헤더 및 월·주·일 포인터 이동 위젯 테스트 통과
  - 40ms 간격의 같은 방향 마우스 두 틱이 두 달 이동하는 회귀 검증 통과
  - `./tool/flutter.sh analyze --no-pub` 통과

### 2026-08-21 스케줄 모드 주말·공휴일 날짜 색상 (#46)

- 주간과 일간 스케줄 모드가 공유하는 날짜 헤더에 월간 캘린더와 동일한 날짜
  색상 규칙을 적용했다.
- 선택된 날짜는 `onPrimaryContainer` 대비색을 최우선으로 사용한다. 선택되지
  않은 날짜는 공휴일·일요일 빨강, 토요일 파랑, 평일 기본 표면색 순으로
  표시한다.
- 날짜의 실제 `weekday`를 사용하므로 주 시작 요일과 로케일에 따라 열 순서가
  달라져도 토·일 판정은 유지된다.
- 검증:
  - 라이트 테마 주간 스케줄의 일요일·토요일·공휴일·선택일 색상 테스트 통과
  - 다크 테마 일간 스케줄의 일요일 색상 테스트 통과
  - 기존 스케줄 시간 스크롤 및 주 이동 위젯 테스트 통과
  - `./tool/flutter.sh analyze --no-pub` 통과

### 2026-08-21 macOS 목록 모드 주·일간 마우스 이동 (#47)

- macOS 목록형 주간·일간 보기에서 일반 마우스의 우세한 가로 또는 세로 휠
  축을 이전·다음 기간 이동으로 처리한다.
- 마우스 한 틱은 #44의 목표 페이지 큐를 통해 정확히 한 주 또는 하루를
  이동한다.
- 스케줄 모드에서는 세로 마우스 입력을 외부 기간 이동으로 사용하지 않아
  시간대 내부 세로 스크롤을 유지한다.
- 트랙패드는 기존처럼 가로축이 명확한 입력만 기간 이동으로 처리해 관성 세로
  스크롤과 충돌하지 않는다.
- 검증:
  - macOS 목록 모드 주간 세로 휠 및 주·일간 가로 휠 이동 테스트 통과
  - macOS 스케줄 일간의 세로 휠이 날짜를 바꾸지 않는 테스트 통과
  - `./tool/flutter.sh analyze --no-pub` 통과

### 2026-08-17 Siri 변경 후속 처리 자가검증 및 보완

- 앱이 종료된 상태에서 App Intent가 일정을 변경해도 후속 작업이 유실되지
  않도록 iOS/macOS App Group에 영속 변경 큐를 추가했다.
  - 변경 ID, 작업 종류, 변경 전후 알림 분 값을 기록한다.
  - 앱 실행·복귀 시 큐를 읽어 해당 일정의 알림과 알람만 취소·재예약한다.
  - Apple 위젯과 Google Drive 대기 변경까지 성공한 뒤에만 큐 항목을 제거한다.
  - 실패 항목은 남겨 다음 실행·복귀에서 재시도하고, 실행 중 실패는 사용자에게
    일정 저장은 완료됐지만 후속 처리가 보류됐다고 안내한다.
- Siri 변경 한 건마다 전체 일정을 재예약하던 O(N) 처리를 제거하고 변경된
  일정 ID만 처리한다. 앱 시작 예약 복구와 Siri 큐 처리는 순차 실행한다.
- 앱 시작 예약 복구는 삭제된 일정의 기존 알림·알람도 취소한 뒤 활성 일정만
  다시 예약한다.
- 앱 내부 Signal 명령은 제목·날짜·시간·분류 등 필수 정보를 먼저 수집한 뒤,
  실제 변경 직전에 한 번만 실행 확인을 요청한다.
- 앱 내부 확인 상태를 전역 변수에서 각 `DailySignalCommandIntent` 인스턴스의
  상태로 변경해 동시에 실행된 명령 사이에서 삭제 확인이 공유되지 않게 했다.
- 음성 서비스 시작, 권한, 인식 실패, 취소 및 Signal 결과 누락 문구를 시스템
  언어에 따라 한국어·영어·일본어·중국어 번체로 반환한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 165개 통과
  - iPhone Simulator 대상 iOS Debug 빌드 통과
  - macOS Debug 빌드 통과
  - 실제 기기에서 앱이 완전히 종료된 상태의 Siri 추가·수정·삭제 후 앱 재실행,
    알림·알람·위젯·Drive 후속 처리 확인은 수동 검증이 필요하다.

#### 종료 상태 실사용 검증 결과

- iPhone 17 Simulator와 `/Users/kimhwi/Applications/Daily Test.app`을 최신
  Debug 빌드로 데이터 유지 업데이트했다.
- iOS/macOS 앱을 완전히 종료한 상태에서 AppIntent가 생성하는 것과 동일한
  SQLite 변경과 App Group 영속 큐를 만든 뒤 앱을 재실행했다.
  - 추가 일정이 캘린더 DB와 화면에 반영됐다.
  - iOS UserNotifications 예약 추가 로그와 위젯 스냅샷 갱신을 확인했다.
  - 삭제 변경 재실행 시 예약 취소 경로가 실행되고 큐가 비워졌다.
  - iOS/macOS 모두 추가 및 삭제 큐가 성공 후 `[]`로 정리됐다.
- 검증 중 Google 계정 미연결 오류가 로컬 후속 처리 완료까지 막아 큐가 남는
  결함을 발견해 수정했다.
  - 알림·알람·위젯이 성공하면 Siri 큐는 완료 처리한다.
  - Drive 실패는 일정의 `sync_status=pending` 또는 `pending_delete`로 별도
    유지하며 계정 연결 후 기존 동기화 재시도 경로가 처리한다.
- 검증용으로 만든 iOS/macOS 일정과 삭제 tombstone은 확인 후 모두 완전
  제거했다. 기존 사용자 데이터는 변경하지 않았다.
- 물리 iPhone은 검증 당시 Xcode에서 Offline 상태였다. 실제 Siri 시스템
  오버레이 호출 자체는 물리 기기가 다시 연결된 뒤 최종 확인이 필요하다.

### 2026-08-15 앱 내부 Signal 실행 안정화 및 직접 입력

- 앱 내부 LLM 버튼의 Signal 패널은 Apple 공개 API인 Speech,
  AVFoundation 및 App Intents 경로를 그대로 사용한다.
- 음성 입력 중 중지 버튼은 인식 내용을 버리지 않고 현재 발화를 확정해
  실행한다. 닫기 및 앱 비활성화는 실행 없이 인식을 취소한다.
- 일정 추가·수정·삭제로 판단되는 명령은 실행 전에 앱 내부 확인 단계를
  거친다. 네이티브 App Intent에도 확인 여부를 전달하므로 Flutter 쪽 문장
  판별이 누락되더라도 변경 명령이 바로 실행되지 않는다.
- 오류 상태를 누락 정보, 시스템 인증 취소, 시스템 인증 실패, 사용자 취소,
  실제 실행 실패로 구분한다. 누락 정보 응답은 기존 대화 문맥을 유지해
  후속 답변을 받을 수 있다.
- 음성 인식이 어렵거나 시스템 Siri 오버레이를 사용할 수 없는 환경을 위해
  키보드 아이콘으로 여는 텍스트 입력 경로를 추가했다. 이 경로도 음성과
  동일한 `DailySignalCommandIntent`를 실행한다.
- Siri/App Intent 일정 변경 후 Flutter에 이미 존재하던 일정 범위 갱신,
  Apple 위젯 갱신 및 Google Drive 대기 변경 동기화 호출은 유지했다.
- 실제 보완이 필요했던 알림·알람 갱신은 다음처럼 처리했다.
  - 변경된 일정의 기존 일반 알림과 AlarmKit 예약을 먼저 취소한다.
  - 삭제된 일정은 취소만 수행한다.
  - 활성 일정은 현재 설정으로 일반 알림과 알람을 다시 예약한다.
- 음성 인식 최대 시간은 30초, 무음 확정 기준은 2초로 조정했고 다른 오디오와
  충돌을 줄이도록 iOS 오디오 세션을 구성했다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 165개 통과
  - `test/core/siri/signal_voice_service_test.dart` 2개 통과
  - 텍스트 변경 명령이 확인 전에는 네이티브로 전달되지 않고, 사용자가
    `실행`을 누른 뒤 `confirmed: true`로 전달되는 위젯 테스트 통과
  - 주간 캘린더 진입·스와이프 위젯 집중 테스트 통과
  - iPhone Simulator 대상 iOS Debug 빌드 통과
  - macOS Debug 빌드 통과
- 설치:
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`의 기존
    `com.littlebit0.daily` 앱에 업데이트 설치했다.
  - `/Users/kimhwi/Applications/Daily Test.app`의
    `com.littlebit0.daily.test` 앱에 3.0.1(3.0.1)을 업데이트 설치했다.
- 실기기와 같은 Apple Siri 텍스트 오버레이 자동 검증은 macOS 컴퓨터 제어
  API가 `Fn` 단독 입력 및 시스템 전역 Siri 오버레이 접근을 지원하지 않아
  수행하지 못했다. 확인 과정에서 Siri 단축키는 기존 `Fn+S`로 원상복구했다.
  앱 내부 텍스트 입력과 음성 입력은 동일한 App Intent를 사용하므로 코드 및
  빌드 경로는 공통으로 검증됐다.
- iPhone 17 Simulator 설치본 수동 검증:
  - 첫 실행의 음성 인식 및 마이크 시스템 권한 안내가 정상 표시됐다.
  - 음성 인식이 불가능한 시뮬레이터에서도 키보드 아이콘으로 텍스트 입력을
    열 수 있었다.
  - `오늘 일정 알려줘`를 입력해 `2026년 8월 15일 토요일`, 광복절 및 등록된
    일정 없음 응답을 실제 App Intent에서 받았다.
  - `내일 오전 9시부터 10시까지 검증 일정 추가`는 즉시 저장되지 않고
    `실행/취소` 확인 상태로 전환됐다. `취소`를 눌러 테스트 일정은 생성하지
    않았다.

### 2026-08-15 앱 내부 Signal 음성 실행

- 사용자의 최종 지시에 따라 앱 내부 LLM 버튼은 단축어 URL이나 Siri 시스템
  화면을 호출하지 않는다. Apple이 공개한 `Speech`, `AVFoundation`, App
  Intents API만 사용하는 앱 내부 Signal 음성 흐름으로 교체했다.
- 버튼을 누른 시점에만 마이크와 음성 인식 권한을 요청하고 즉시 듣기를
  시작한다. 음성을 텍스트로 변환한 뒤 기존 `DailySignalCommandIntent`에
  전달하고, 실행 결과는 앱에 표시하면서 시스템 음성으로 읽는다.
- 필수 정보가 부족하면 추가 정보를 요청하고, 다음 발화를 앞선 명령에 이어
  다시 해석한다.
- 일정 변경 성공 직후 `eventsInRangeProvider` 전체와 선택 날짜 공급자를
  무효화하고 Apple 위젯을 갱신해 월간·주간·일간·상세 화면의 반영 지연을
  방지한다.
- iOS 권한 문구는 한국어, 영어, 일본어, 중국어 번체로 현지화했다. macOS
  샌드박스에는 오디오 입력 권한을 추가했다.
- 심사 안전 경계:
  - 비공개 Siri API, Siri URL scheme, 접근성 자동 조작을 사용하지 않는다.
  - 앱이 Siri 시스템 UI를 가장하지 않고 Daily의 Signal 음성 도구임을
    화면에 명시한다.
  - 권한은 기능 사용 시점에만 요청하며 거부 시 오류와 재시도 상태를
    제공한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - LLM 버튼/달력 레이아웃 회귀 위젯 테스트 통과
  - iPhone Simulator iOS Debug 빌드 통과
  - macOS Debug 빌드 통과
- 이전 기록의 “AI 버튼이 시그널 단축어를 실행한다”는 설명은 더 이상 현재
  동작이 아니다. 그 방식은 사용자가 지적한 잘못된 롤백이었으며 완전히
  제거됐다.
- 데이터 유지 업데이트 설치:
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`의 기존
    `com.littlebit0.daily`에 설치했고, 전후 `daily.sqlite` SHA-256은
    `94fcb0568cb42b11d239bb59e0a0e861384a5772d6b1d6a470cb25a4b76fa89b`로
    동일했다.
  - `/Users/kimhwi/Applications/Daily Test.app`을 업데이트했고, 전후
    `daily.sqlite` SHA-256은
    `93ca987bdd7e0e4688f94e72054651d37291bdff41829d6257770c2d59888064`로
    동일했다.
  - 두 앱 모두 자동 실행하지 않았다.

### 2026-08-15 Siri 응답 스니펫 및 잘못된 받아쓰기 연결 제거

- Siri의 기본 `IntentDialog` 카드는 문자열의 줄바꿈을 한 문단으로 접기 때문에
  일정별 `\n`만으로는 화면에서 행이 분리되지 않았다.
- 오늘, 어제, 내일, 지정 날짜와 Signal 조회 결과를 SwiftUI 기반 App Intents
  시스템 스니펫으로 함께 반환하도록 변경했다. 날짜 안내, 공휴일, 각 일정이
  독립된 행으로 렌더링된다. Siri 음성 안내용 `IntentDialog`도 함께 유지한다.
- 앱 내부 LLM 버튼에 연결돼 있던 `shortcuts://run-shortcut` 호출을 제거했다.
  이 호출은 실제 Siri가 아니라 단축어의 받아쓰기 화면을 열던 잘못된 동작이다.
  버튼은 현재 앱 내부 AI 입력 화면을 연다.
- 실제 Siri 시스템 화면은 사용자가 `Siri야`, 측면 버튼 또는 타이핑으로 Siri를
  호출했을 때 Daily App Intent가 응답한다. 앱이 Siri 시스템 청취 화면을
  강제로 여는 공개 API는 없다.
- 검증 및 설치:
  - iOS Simulator Debug 빌드 통과
  - macOS Debug 빌드 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 162개 통과
  - iPhone 17 Simulator와 macOS `Daily Test.app`에 업데이트 설치했으며 자동
    실행하지 않았다.

### 2026-08-15 Siri 어제 조회 및 일정별 응답 구분 보완

- `어제`가 지원 액션에 없어서 Apple Intelligence 해석 결과가 `오늘`로
  잘못 귀결될 수 있던 문제를 수정했다.
  - `yesterday`를 독립 `DailySiriAction`과 생성형 액션으로 추가했다.
  - 한국어 `어제`, 영어 `yesterday`, 일본어 `昨日`, 중국어 번체 `昨天`을
    규칙 기반으로 먼저 분류한다.
  - 어제 자정부터 오늘 자정 전까지의 일정만 조회하며 Siri 실행 기록에도
    `어제 일정 조회`로 구분한다.
- 일정 응답은 Siri 화면에서 단일 줄바꿈이 접힐 수 있는 점을 고려해 일정과
  안내 문장 사이를 빈 줄로 분리한다. 각 일정은 독립된 문장 블록이다.
- 수정본을 iPhone 17 Simulator와 macOS `Daily Test.app`에 데이터 유지
  업데이트 설치했고 자동 실행하지 않았다.
- 검증:
  - iOS Simulator Debug 빌드 통과
  - macOS Debug 빌드 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
- 앱 내부 버튼에서 Siri 시스템 청취 UI를 직접 여는 공개 API는 없다.
  `INPreferences.requestSiriAuthorization`은 Siri가 Daily Intent를 호출할 권한만
  요청하며 Siri UI를 실행하지 않는다. 기존 버튼의 `shortcuts://run-shortcut`
  호출은 실제 Siri가 아니라 단축어 실행이므로 제품 동작을 변경하려면 앱 내부
  음성 인식 또는 사용자 Siri 직접 호출 방식 중 결정이 필요하다.

### 2026-08-15 Siri 일정 안내 문장 개선

- 오늘·내일·지정 날짜 조회에서 각 일반 일정을 줄바꿈으로 분리해 일정 하나가
  한 줄씩 전달되도록 변경했다.
- 공휴일 안내가 실제로 앞에 존재할 때에만 첫 일반 일정에 `또한`에 해당하는
  언어별 연결어를 사용한다. 공휴일이 없으면 일정 문장을 바로 시작한다.
- iOS 26/macOS 26 이상에서 Apple Intelligence가 사용 가능한 경우에는
  Foundation Models가 사실 기반 문장의 표현만 자연스럽게 다듬는다.
  - 날짜, 요일, 시각, 일정 제목, 공휴일, 개수와 줄 수가 바뀌지 않았는지
    검증한다.
  - 검증 실패, 모델 미지원 또는 생성 실패 시에는 정확한 규칙 기반 원문을
    그대로 사용한다.
- Apple 공개 App Intents API는 앱 버튼이 Siri 시스템 청취 UI를 직접
  시작하도록 허용하지 않는다. 현재 앱 내부 AI 버튼은 기존 `시그널` 단축어
  실행을 유지한다. 이를 변경하려면 앱 내부 음성 인식으로 Daily 명령을 받는
  방식 또는 사용자가 Siri를 직접 호출하도록 안내하는 방식 중 제품 결정을
  받아야 한다. 비공개 URL scheme 우회는 배포 앱에 적용하지 않았다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 162개 통과
  - iPhone Simulator 대상 iOS Debug 빌드 통과
  - macOS Debug 빌드 통과

### 2026-08-15 Siri 시스템 언어 응답

- Siri/App Intent가 반환하는 문장을 기기의 시스템 선호 언어에 맞춰 매 실행
  시 선택하도록 수정했다.
- 지원 언어는 앱과 동일한 한국어, 영어, 일본어, 중국어 번체다.
  - `ko`는 한국어, `en`은 영어, `ja`는 일본어로 응답한다.
  - `zh-Hant`, 대만, 홍콩, 마카오 중국어는 중국어 번체로 응답한다.
  - 지원하지 않는 시스템 언어 및 중국어 간체는 영어로 폴백한다.
- 다음 Siri 출력이 모두 같은 시스템 언어를 사용한다.
  - 오늘·내일·지정 날짜·다음 일정·검색·D-day 조회 결과
  - 일정 추가·수정·삭제 완료 응답
  - 누락된 날짜·시간·제목과 검색어를 묻는 후속 질문
  - 일정 수정·삭제 대상 선택 및 삭제 확인
  - 수정·삭제 시 시스템 인증 사유
  - 데이터 접근·일정 검색·중복 일정·잘못된 시간 오류
- 날짜와 시각 형식도 선택된 시스템 언어의 지역 형식을 사용한다. 앱 내부에서
  사용자가 선택한 표시 언어와는 별개이며, Siri 응답은 시스템 선호 언어를
  따른다.
- 검증:
  - macOS Debug 제품 빌드 및 App Intents 메타데이터 생성 통과
  - iPhone 17 Simulator 대상 iOS Debug 제품 빌드 및 App Intents 메타데이터
    생성 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - Siri 기록 상세 화면 및 전체 위젯 테스트 54개 통과
  - iOS/macOS XCTest에 지원 언어 식별자와 영어 폴백 검증을 추가했다. 기존
    Xcode 테스트 타깃의 리소스 번들 문제로 네이티브 XCTest 실행은 별도 보완이
    필요하다.
- 테스트 설치 업데이트:
  - `/Users/kimhwi/Applications/Daily Test.app`을 Apple Development 서명
    빌드로 업데이트했고 기존 macOS 데이터베이스 해시가 유지됐다.
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`의 기존 앱에
    업데이트 설치했고, 설치 전후 `daily.sqlite` SHA-256이 동일했다.
  - 두 앱 모두 자동 실행하지 않았다.

### 2026-08-15 Siri 공휴일 일정 인식

- 원인: 한국 공휴일은 `event_records` SQLite에 저장되지 않고 Flutter의
  `KoreanHolidayService`가 화면 조회 시 동적으로 합치는 읽기 전용 일정이다.
  네이티브 Siri 조회는 SQLite만 읽고 있어 오늘·내일·지정 날짜·다음 일정 및
  검색에서 공휴일이 누락됐다.
- iOS/macOS 공유 Siri 계층에 Flutter와 같은 한국 공휴일 계산을 추가했다.
  - 고정 공휴일
  - 설날 연휴, 부처님 오신 날, 추석 연휴
  - 주말·중복 공휴일에 따른 대체공휴일
  - 2027년 이후 노동절과 2026년 이후 제헌절 규칙
- Siri의 오늘·내일·지정 날짜·다음 일정 조회와 일정 검색에는 저장 일정과
  동적 공휴일을 시간순으로 함께 반환한다.
- 공휴일은 읽기 전용이므로 Siri 일정 수정·삭제 대상 목록과 Spotlight 수정
  엔티티에는 포함하지 않는다.
- 설정의 `공휴일 표시`가 꺼져 있으면 Siri 조회와 검색에서도 공휴일을 숨긴다.
- 공휴일 제목은 Siri 시스템 응답 언어에 맞춰 한국어, 영어, 일본어, 중국어
  번체로 반환하며 각 언어 제목과 `공휴일` 검색어를 인식한다.
- 검증:
  - macOS Debug 제품 빌드 및 App Intents 메타데이터 생성 통과
  - iPhone 17 Simulator 대상 iOS Debug 제품 빌드 및 App Intents 메타데이터
    생성 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - Siri 기록 상세 화면 및 전체 위젯 테스트 54개 통과
  - iOS/macOS XCTest에 2026년 설날, 부처님 오신 날 대체공휴일, 광복절,
    광복절 대체공휴일 생성 검증을 추가했다. 기존 Xcode 테스트 타깃의 리소스
    번들 문제로 네이티브 XCTest 실행은 별도 보완이 필요하다.
- 설치:
  - `/Users/kimhwi/Applications/Daily Test.app`을 Apple Development 서명
    빌드로 데이터 유지 업데이트했다.
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`에 데이터 유지
    업데이트했고 설치 전후 `daily.sqlite` SHA-256이 동일했다.
  - 두 앱 모두 자동 실행하지 않았다.

### 2026-08-15 Siri 정확한 일정 안내, 필수 정보 수집, 앱 AI 진입

- 오늘·내일·지정 날짜 일정 조회는 조회 날짜의 연·월·일·요일을 먼저 말하고,
  공휴일과 일반 일정을 구분해 안내한다.
  - 공휴일은 `이날은 공휴일로 광복절입니다` 형태로 별도 안내한다.
  - 시간 일정은 시작과 종료 시각을 함께 말한다.
  - 종일 및 연속일정은 시작일과 실제 마지막 날짜를 함께 말한다.
  - 시각은 앱 설정 `use24HourTime`을 읽어 12시간제 또는 24시간제로 출력한다.
  - 다음 일정, 일정 검색, D-day 결과도 시작·종료 날짜와 시각을 모두 말한다.
- Siri 일정 추가·수정은 제목, 날짜/시간 또는 명시적 종일 여부, 분류를 필수로
  수집한다.
  - 시간 일정은 종료 시각까지 없으면 후속 질문을 한다.
  - `8월 20일부터 30일`, `8월 20일부터 9월 10일` 같은 한국어 종일 날짜
    범위를 인식하고 DB의 배타적 종료일 규칙에 맞춰 저장한다.
  - 분류는 SharedPreferences의 `eventCategories`를 읽어 실제 사용자 분류 ID와
    색상으로 저장하며, 존재하지 않는 분류는 다시 질문한다.
  - 알림, 알람, D-day, 장소, 링크, 날씨, 메모는 사용자가 명시한 경우에만
    저장하고, 추가 시 언급하지 않은 값은 비활성 또는 빈 값으로 둔다.
  - App Intent로 변경된 일정은 Flutter UI 범위 전체를 즉시 무효화하고,
    현재 일정의 알림·알람 예약 및 Google Drive 대기 변경 동기화를 갱신한다.
- 이 단계에서 앱 내부 AI 버튼에 적용했던 단축어 URL 실행은 이후 사용자
  지시에 따라 제거됐다. 현재 동작은 위 `앱 내부 Signal 음성 실행` 항목을
  기준으로 한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 162개 통과
  - iPhone Simulator 대상 iOS Debug 제품 빌드 및 App Intents 메타데이터 생성
    통과
  - macOS Debug 제품 빌드 및 App Intents 메타데이터 생성 통과
  - iOS/macOS XCTest에 다월 종일 날짜 범위의 배타적 종료일 검증을 추가했다.
    기존 테스트 타깃의 `TEST_HOST` 및 Swift Package 리소스 번들 문제로
    네이티브 XCTest 실행 자체는 아직 별도 보완이 필요하다.
- 수동 확인 필요:
  - 앱 내부 Signal에서 제목·날짜·시간·분류 중 하나를 빠뜨렸을 때 각각 후속 질문하는지,
    12/24시간 설정을 바꾼 뒤 조회 문장이 즉시 바뀌는지 확인한다.
- 테스트 앱 업데이트 설치:
  - iPhone 17 Simulator `BF524643-403E-4212-ACB7-621E11279532`의 기존
    `com.littlebit0.daily` 앱에 3.0.1(3.0.1)을 업데이트 설치했다. 설치 전후
    `daily.sqlite` SHA-256은
    `94fcb0568cb42b11d239bb59e0a0e861384a5772d6b1d6a470cb25a4b76fa89b`로
    동일하다.
  - `/Users/kimhwi/Applications/Daily Test.app`에 Apple Development 서명된
    3.0.1(3.0.1) 빌드를 업데이트 설치했다. 설치 전후 macOS `daily.sqlite`
    SHA-256은
    `40e4380801d1be593d8b59541bd846c76d486a61d15746f40783ea43fa8115e6`로
    동일하다.
  - 두 앱 모두 자동 실행하지 않았다.
### 2026-08-21 GitHub 이슈 #43 반복 일정 삭제 범위 문구

- 반복 일정 삭제 범위 선택에서만 `전체 반복`을 `전체 삭제`로 변경했다.
- 반복 일정 수정과 날짜 드래그 이동의 범위 선택은 기존 `전체 반복`을 유지한다.
- 한국어, 영어, 일본어, 중국어 번체 문구와 위젯 테스트를 추가했다.
- 공통 상세 패널의 전체 범위·번역 검증 4개가 통과했다.

### 2026-08-21 GitHub 이슈 #45 상하 스크롤 주간·일간 헤더

- 상하 스크롤 주간 헤더는 선택일이 속한 `연·월·월 기준 주차`를 표시한다.
- 상하 스크롤 일간 헤더는 `연·월`만 표시하며 주차를 표시하지 않는다.
- 주차는 설정의 주 시작 요일을 반영하고, 월 경계 주는 선택일이 속한 월을
  기준으로 계산한다.
- 한국어, 영어, 일본어, 중국어 번체의 자연스러운 표기를 적용했다.
- 월초·연초 경계와 주간/일간/월간 표기 테스트 5개가 통과했다.

### 2026-08-21 GitHub 이슈 #48 스케줄 종일 일정 높이

- 스케줄 주간·일간의 종일 일정 영역은 실제 일정 행 수만큼 높아진다.
- 4개를 초과하면 높이를 더 늘리지 않고 내부 세로 스크롤로 모든 일정에
  접근할 수 있다. 기존 `+N` 축약 표시는 제거했다.
- 전체 UI 글자 크기 설정에 맞춰 종일 일정 행과 영역 높이를 함께 조정한다.
- 종일 일정이 없거나 표시가 꺼져 있으면 영역 자체를 만들지 않는다.
- 0·1·3·6개 일정, 4행 초과 내부 스크롤, 주간 7열과 글자 크기 3단계를
  포함한 스케줄 위젯 테스트 10개가 통과했다.

### 2026-08-21 GitHub 이슈 #49 설정 의미별 아이콘

- 설정 메인과 알림, 화면, 달력, 개인정보, 분류, AI, 계정, 앱 정보의 설정
  항목 왼쪽에 기능 의미별 Material 아이콘을 추가했다.
- 공통 아이콘 크기는 22px이며 직접 만든 슬라이더·칩 행도 ListTile과 같은
  선행 영역을 사용해 제목 정렬을 맞췄다.
- 아이콘은 인접한 제목을 보조하는 장식 요소로 중복 음성 안내가 되지 않도록
  접근성 트리에서 제외했다. 기존 비활성·상태·위험 색상은 유지한다.
- 393×852 화면과 1.3배 글자에서 설정 메인 전체, 알림·계정 하위 화면을
  스크롤하며 모든 목록/스위치 행의 아이콘 존재와 오버플로 부재를 확인하는
  위젯 테스트가 통과했다.

### 2026-08-21 GitHub 이슈 #14 일정 Todo 통합 및 안전 마이그레이션

- 모든 사용자 일정에 `completed` 상태를 추가하고 로컬 DB 스키마를 7로
  올렸다. 기존 일정은 미완료로 마이그레이션되며 생성·수정·재시작과 Google
  Drive v2 이벤트 파일을 거쳐 기기 간 유지된다.
- 앱 시작 마이그레이션 순서는 다음과 같다.
  1. 연결된 Google 계정이 있으면 원격 v2 이벤트를 비대화형으로 읽는다.
  2. 로컬 대기 변경을 우선 보존하면서 원격의 더 최신 변경을 병합한다.
  3. SQLite 일관성 스냅샷을 생성한다.
  4. 작업 복사본에서 스키마와 데이터를 마이그레이션하고 검증한다.
  5. 검증 성공 후에만 원본 DB를 원자적으로 교체하고 즉시 Drive 백업한다.
- 원격 복원 또는 로컬 마이그레이션이 실패하면 캘린더 진입을 차단하고 재시도
  화면을 표시하며 원본 DB는 변경하지 않는다. 백업만 실패하면 로컬 완료
  상태를 유지하고 모든 변경을 대기 상태로 남겨 기존 제한 재시도로 보낸다.
- 빠른 보기는 사용자 분류별 Todo 카드로 변경했다. iOS는 한 줄에 2개,
  macOS는 창 너비에 따라 1~4개를 표시한다. 체크박스는 완료 상태만 즉시
  변경하고 제목은 일정 상세를 연다.
- 월·주·일 캘린더에서 연 일정 상세 화면에도 Todo 체크박스를 표시한다.
  읽기 전용·시스템·공휴일 일정은 비활성화하고, 사용자 일정은 기존 일정 명령
  경로로 저장·알림·알람·동기화·위젯을 함께 갱신한다.
- 완료 일정은 월간·주간·일간·검색·상세와 Apple 위젯에서 회색 이중 취소선으로
  표시한다. 완료 시 기존 알림과 알람은 취소하고 미완료로 되돌리면 다시
  예약한다. 아침 브리핑에서는 완료 일정을 제외한다.
- iOS 17/macOS 14 이상 Apple 위젯의 오늘 일정 체크박스는 스냅샷을 즉시
  갱신하고 앱이 다음으로 실행 또는 복귀할 때 공유 App Group 작업을 DB와
  Drive 대기 동기화에 반영한다. 이전 OS는 읽기 전용 표시를 유지한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 마이그레이션·동기화·DB·명령·달력·위젯·통합 대상 테스트 125개 통과
  - `./tool/flutter.sh build macos --debug --no-pub` 통과
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` 통과
- 실기기에서는 기존 사용자 DB의 시작 마이그레이션 화면, Google Drive 백업
  실패 후 재시도, 홈/잠금화면 위젯 체크와 앱 복귀 후 반영을 최종 확인해야
  한다.

### 2026-08-21 GitHub 이슈 #35 개인정보 보호형 UX 분석

- macOS와 iOS 공유 Flutter 계층에 선택형 익명 사용성 분석을 추가했다.
  - 기본값은 비활성화이며 설정의 개인정보 화면에서 사용자가 직접 허용해야
    한다.
  - 사용자는 언제든 수집을 끄거나 기기에 대기 중인 분석 데이터를 삭제할 수
    있다. 끄면 대기 큐도 즉시 삭제된다.
- 허용하는 데이터는 고정 스키마의 화면·기능·결과 열거값과 제한된 숫자값뿐이다.
  - 화면 및 월·주·일·빠른 보기 사용
  - 일정 편집 열기·완료·취소와 저장 성공·실패
  - 검색·필터·위젯 사용
  - 동기화 종류·트리거·결과·분류된 오류·소요 시간
  - 앱 시작 소요 시간과 느린 프레임 묶음
  - 앱 버전, 플랫폼, OS 주 버전
- 일정 제목·메모·장소·링크, 검색어·자유 입력, 이름·이메일·계정 정보,
  인증 토큰, 위치, 광고 식별자와 지속적인 기기 식별자는 스키마 단계에서
  허용하지 않는다.
- 세션 ID는 앱 프로세스 메모리에만 존재한다. 전송용 이벤트 ID는 재전송 중복
  제거에만 사용하며 서버에는 원문 ID를 저장하지 않는다.
- 오프라인 큐는 기기에서 최대 200개·7일로 제한하고 중복 요청을 합치며 제한된
  간격으로 재시도한다. 분석 초기화·환경 조회·네트워크·서버 실패는 앱 시작,
  일정 명령, Google Drive 동기화 결과에 영향을 주지 않는다.
- `tool/analytics_receiver.dart`에 첫 번째 당사자 집계 수신기를 추가했다.
  - `POST /v1/events`와 `GET /health`만 제공한다.
  - 요청은 64 KiB·25개 이벤트로 제한하고 고정 스키마를 다시 검증한다.
  - 일별 집계 횟수와 성능 합계만 90일 보관하며, 이벤트 ID의 단방향 중복 제거
    해시는 7일 보관한다.
  - 원본 요청, 세션·이벤트 ID, 계정, 일정 내용과 네트워크 주소는 저장하지 않는다.
- 개인정보 처리방침, 개인정보·보안 문서, README와 Ubuntu 배포 문서를 현재
  구현에 맞게 갱신했다. 공개 릴리스 전에 App Store Connect에서
  `Usage Data > Product Interaction > Analytics`, 신원 비연결, 추적 아님으로
  신고해야 한다.
- 검증:
  - 실제 로컬 HTTP 수신기에 안전한 요청은 202, 메모 필드가 섞인 요청은
    400으로 거부되는 통합 테스트 통과
  - 초기화 실패 격리, 기본 비활성, 동의, 삭제, 큐 제한, 재시도, 중복 제거,
    집계 전용 저장 테스트 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 225개 통과
  - macOS Debug 빌드 통과
  - iOS Simulator Debug 빌드 통과
- 운영 잔여 작업:
  - 실제 Ubuntu 수신 서버와 HTTPS 도메인은 아직 연결하지 않았다.
  - 공개 전송을 활성화하려면 `docs/ANALYTICS_DEPLOYMENT.md`대로 서버를 배포하고
    macOS/iOS 릴리스 빌드에 동일한 `DAILY_ANALYTICS_ENDPOINT`를 주입한 뒤 실제
    집계 파일에 허용된 값만 저장되는지 최종 확인해야 한다.

### 2026-08-21 GitHub 이슈 #36 Android 태블릿 반응형 UI 보류

- #36은 7인치·10인치 Android 태블릿 전용 반응형 UI 이슈다.
- 현재 사용자의 명시적 플랫폼 경계인 `Android와 Windows는 수정하지 않음`에
  따라 이 macOS/iOS 작업에서는 코드를 변경하지 않았다.
- Android 담당 환경에서 600dp·840dp 구간, Navigation Rail, 캘린더/상세 2단
  구조, 태블릿 다이얼로그 폭과 7·10인치 세로·가로 에뮬레이터 검증이 필요하다.

### 2026-08-21 GitHub 이슈 #37 공휴일 색상과 날짜 배경

- 고정 공휴일 분류는 이름 변경·삭제는 막고 색상 편집은 허용한다.
- 공휴일 분류 색상은 동적 공휴일 일정과 월·주·일 캘린더에 즉시 반영된다.
- `공휴일 날짜 배경` 설정으로 같은 색상의 날짜 배경을 별도로 켜고 끌 수 있다.
  배경을 꺼도 지정한 분류 색상은 보존된다.
- 색상과 배경 설정은 로컬 설정과 Google Drive v2 설정 백업·복원에 포함되며
  이전 설정에 필드가 없으면 배경 표시를 켠 기존 호환 기본값을 사용한다.
- 공휴일 배경은 라이트 14%, 다크 22% 투명도를 사용하고 선택 날짜와 겹치면
  선택 상태가 우선한다.
- 관련 설정·월간·스케줄·Drive 동기화 테스트 56개가 통과했다.

### 2026-08-21 GitHub 이슈 #38 일정 제목 정렬

- 설정에서 일정 제목 정렬을 `기본`과 `가운데` 중 선택할 수 있다.
- 선택값은 월간 일정 칩과 주·일 목록 및 스케줄의 일정 제목에만 적용된다.
- macOS 오른쪽 하루 상세 패널, 빠른 보기 Todo, 검색 결과와 일정 상세 화면은
  설정과 무관하게 기존 왼쪽 정렬을 유지한다.
- 설정은 로컬과 Google Drive v2 설정에 저장·복원되며 이전 설정은 기본 정렬을
  사용한다.
- 정렬만 변경하고 기존 일정 행 높이, 표시 개수, 말줄임 조건은 바꾸지 않는다.
- 월간·스케줄·상세 패널 관련 대상 테스트가 통과했다.

### 2026-08-21 GitHub 이슈 #39 분류 순서와 일정 정렬 우선순위

- 각 분류 왼쪽에 점 6개 모양의 지연형 드래그 핸들을 배치했다. 핸들을 길게
  눌러 순서를 변경하며 나머지 영역의 표시·편집 동작은 유지한다.
- 일정 정렬을 `분류 우선`과 `시간 우선` 중 선택할 수 있다.
- 분류 우선은 저장된 분류 순서 다음 시작 시각을, 시간 우선은 시작 시각 다음
  분류 순서를 비교한다. 이후 종료 시각·제목·ID를 사용해 동률을 결정적으로
  정렬한다.
- 선택은 월·주·일·빠른 보기와 일정 목록에 공통 적용되며 원본 일정의 시간은
  바꾸지 않는다.
- 분류 순서와 정렬 선택은 로컬 및 Google Drive v2 설정에 저장·복원된다.
- 설정 UI 재정렬·우선순위 조작 테스트와 관련 정렬·캘린더·Drive 테스트 63개가
  통과했다.

### 2026-08-21 GitHub 이슈 #40 반복 일정 종료일 포함

- 반복 종료일 `until`은 시각이 아니라 사용자의 달력 날짜를 기준으로 포함
  범위로 판정한다. 종료일 당일에 발생하는 시간 일정이 종료일 자정보다 늦다는
  이유로 누락되지 않는다.
- 시간·종일 일정과 매일·매주·매월·매년 반복에서 종료일 발생은 정확히 한 번
  포함되고 다음 발생은 생성되지 않는다.
- 월말·연말 경계를 포함한 반복 확장 테스트 7개가 통과했다.

### 2026-08-21 GitHub 이슈 #41 라이트 모드 노란색 대비

- 사용자의 2026-08-21 지시에 따라 구현을 전부 롤백하고 보류했다.
- 노란색 전용 전경색·테두리 계산 도우미와 해당 테스트를 제거했으며 월간,
  주·일, 빠른 보기, 상세·검색, Apple 위젯은 이슈 적용 전 색상 경로를 사용한다.
- 이 이슈는 추후 별도 방향을 정하기 전까지 미적용 상태다.

### 2026-08-21 GitHub 이슈 #42 일정 날짜 이동과 날짜별 수동 순서

- 월간 일정은 길게 누른 뒤 다른 날짜 또는 같은 날짜의 원하는 행으로 이동할
  수 있다. 일반 시간 일정은 벽시계 시작 시각과 기간을, 종일·연속 일정은
  배타적 종료일 기준 일수를 유지한다.
- 일정 바를 짧게 누르면 바가 여러 날짜에 걸쳐 있어도 실제 포인터 아래 날짜를
  계산해 해당 일자를 즉시 선택한다.
- 일정 길게 누르기는 일반 날짜 범위 선택보다 먼저 시작하고, 이동이 시작되면
  월간 그리드와 상하 연속 달력의 범위 선택 상태를 모두 취소한다.
- 반복 일정은 `이 일정만`, `이후 일정`, `전체 반복` 범위를 먼저 묻는다.
  - 이후/전체 이동은 반복 종료일과 제외일도 같은 일수만큼 옮긴다.
  - 횟수 제한 반복의 이후 이동은 이미 지난 발생을 제외한 남은 횟수만 새
    시리즈에 부여한다.
  - 날짜 차이는 UTC 달력 날짜로 계산하고 실제 시각은 다시 구성해 DST 전환
    구간에서도 사용자 벽시계 시각이 변하지 않는다.
- 날짜별 수동 순서는 전역 분류/시간 우선순위보다 먼저 적용한다. occurrence ID를
  사용해 반복 발생별 순서를 구분하며 날짜별 수정 시각과 기기 ID로 Drive 설정
  충돌을 결정한다.
- 일정 이동은 이벤트 변경 백업을, 순서 변경은 설정 백업을 즉시 대기열에 넣는다.
- 월간 일정 바 날짜 선택과 길게 누른 날짜 이동을 포함한 대상 테스트가
  통과했다.

### 2026-08-21 GitHub 이슈 #44 macOS 목록 모드 휠 방향

- macOS 월·주·일 목록 화면의 일반 마우스 휠은 입력 한 틱마다 한 기간 이동을
  순서형 큐에 넣고, 앞 애니메이션이 끝난 뒤 다음 입력을 처리한다.
- macOS의 PageView에는 사용자 스크롤 물리를 비활성화해 바깥 포인터 처리기와
  PageView가 같은 휠 이벤트를 중복 소비하지 않게 했다. 컨트롤러 애니메이션과
  툴바 이동은 그대로 작동한다.
- 트랙패드는 기존 축 판정과 관성 입력 억제 경로를 유지하며, 상하 스크롤
  월간 모드의 일반 스크롤도 변경하지 않는다.
- 월·주·일의 macOS 전용 물리, 트랙패드 이동, 마우스 한 틱 및 연속 두 틱의
  순차 이동을 위젯 테스트로 확인했다.

### 2026-08-21 GitHub 이슈 #46 스케줄 주간·일간 주말 색상

- 스케줄 모드의 날짜 헤더는 주 시작 요일이나 표시 순서가 아니라 실제
  `DateTime.weekday`를 기준으로 일요일을 빨강, 토요일을 파랑으로 표시한다.
- 공휴일은 빨강을 사용하고, 선택된 날짜는 주말·공휴일보다 선택 상태의
  전경색과 배경색을 우선한다. 오늘 표시는 기존 굵기 강조를 유지한다.
- 주간·일간, 라이트·다크, 일요일·월요일 시작 주간과 선택된 주말의 우선순위를
  포함한 스케줄 위젯 테스트 9개가 통과했다.

### 2026-08-21 GitHub 이슈 #47 macOS 목록형 주간·일간 휠 이동

- macOS 목록형 주간·일간에서는 가로 마우스 입력과 일반 마우스의 세로 휠
  한 틱을 각각 한 주·한 일의 이전/다음 이동으로 처리한다.
- 연속 입력은 마지막 대기 목표 페이지를 기준으로 누적해 애니메이션 도중
  방향이 뒤집히지 않는다. 트랙패드의 기존 가로 축 판정과 입력 억제는 유지한다.
- 스케줄형 시간대 영역의 세로 휠은 기간 이동으로 사용하지 않고 내부 시간
  스크롤만 진행한다.
- 목록형 주·일 이동과 스케줄 시간대 내부 스크롤을 실제 macOS 포인터 이벤트로
  확인하는 위젯 테스트가 통과했다.

### 2026-08-21 GitHub 이슈 #50 수동 복원 데이터 안전성

- 설정의 `복원`은 `restoreOnly` 요청만 사용하며 복원 전 업로드나 백업 안내를
  실행하지 않는다. 예약된 로컬 변경 백업은 복원이 실제 종료될 때까지 미룬다.
- 설정 및 모든 v2 일정 파일을 먼저 다운로드·파싱하고, 하나라도 손상되거나
  다운로드에 실패하면 로컬 설정과 일정 DB를 전혀 변경하지 않는다.
- 일정 병합은 Drift 단일 트랜잭션에서 최신 로컬 변경·pending 상태·tombstone
  충돌 규칙을 적용한다. 복원 중 새 로컬 편집도 트랜잭션 시점 데이터로 판정해
  보존하며 이후 별도 백업 대기열에 남긴다.
- 원격 설정을 적용한 뒤 일정 트랜잭션이 실패하면 기존 설정으로 원복한다.
  알림·알람 재조정 실패는 이미 검증·확정된 일정 DB를 되돌리지 않으며 다음 앱
  초기화에서 다시 조정한다.
- 연속 복원 요청은 기존 큐 병합을 유지하고 각 호출자는 자기 복원 종료까지
  대기한다. 인증·네트워크·원격 형식 오류는 완료가 아닌 실패 상태로 남는다.
- 동기화 33개, 설정 버튼 1개, 일정 명령·상세 7개 등 관련 테스트 41개가
  통과했다.

### 2026-08-21 열린 이슈 순차 처리 검증 기록

- 공개 저장소에서 확인된 열린 이슈는 `#14`, `#35`~`#50`이며 번호 순서대로
  조사했다. 이후 수동 검증 결과에 따라 #14, #38, #42, #44를 추가 수정했고
  #41은 롤백해 보류했다.
- `#36`은 Android 태블릿 전용 요구사항이므로 사용자의 Android/Windows 수정
  금지 지시에 따라 코드 변경하지 않았다. Android 작업이 다시 허용될 때 별도
  기기 검증이 필요하다.
- 정적 분석 `./tool/flutter.sh analyze --no-pub`이 오류 없이 통과했다.
- 전체 테스트 `./tool/flutter.sh test --no-pub`에서 234개가 모두 통과했다.
- macOS 디버그 빌드가 성공해
  `build/macos/Build/Products/Debug/Daily Test.app`을 생성했다. GoogleSignIn 외부
  헤더와 일부 Siri API의 폐기 예정 경고는 남아 있으나 빌드 실패는 없다.
- iOS 시뮬레이터 디버그 빌드가 성공해
  `build/ios/iphonesimulator/Runner.app`을 생성했다.
- 이번 순차 처리 결과는 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-08-21 최신 테스트 앱 실제 구동 검증

- 이전 테스트 앱을 정리한 뒤 현재 소스로 만든 앱만 다시 설치해 확인했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`
  - iOS: iPhone 17 시뮬레이터 `BF524643-403E-4212-ACB7-621E11279532`
  - 두 설치본 모두 버전과 빌드가 `3.1.0 / 3.1.0`임을 확인했다.
- macOS 실제 UI에서 설정 아이콘, 익명 분석 설정, 공휴일 색상과 날짜 배경,
  제목 정렬, 분류 순서와 정렬 우선순위, Todo 빠른 보기·완료선·상세 진입,
  목록형 월·주·일 휠 이동, 스케줄 헤더·주말 색상과 종일 영역 높이를 확인했다.
- iPhone 17 실제 UI에서 익명 분석 기본값 OFF, 공휴일 고정 분류와 색상 즉시
  반영, 공휴일 배경 토글, 분류 재정렬, Todo 체크·해제와 상세 진입, 월간
  완료선, 주·일 스케줄 헤더, 주말 색상, 종일 영역 표시 토글을 확인했다.
- iOS에서 2026년 8월 21일부터 23일까지 매일 반복하는 테스트 일정을 생성해
  시작일과 종료일을 포함한 21·22·23일 세 발생이 모두 생성됨을 확인했다.
- 자동 UI 조작 도구는 일정 칩의 길게 누르기 시간을 지정할 수 없어 실제
  날짜 드래그는 실행하지 못했다. 해당 경로는 날짜 이동·반복 범위·수동 순서
  단위 및 위젯 테스트로 보완했고 전체 234개 테스트가 통과했다.
- 반복 일정의 최종 삭제는 데이터를 영구 삭제하므로 실제 실행하지 않았다.
  삭제 범위의 `전체 삭제` 표기는 위젯 테스트와 소스에서 확인했다.

### 2026-08-21 수동 확인 후 #14·#38·#41·#42·#44 보정

- #36은 Android 태블릿 전용이므로 코드와 테스트를 변경하지 않았다.
- #38 가운데 정렬은 월·주·일 캘린더 일정 제목으로만 제한했다. macOS 오른쪽
  하루 패널과 빠른 보기·검색·상세 화면은 왼쪽 정렬을 유지한다.
- #14 일정 상세 화면에 Todo 체크박스를 추가했다. 체크 변경은
  `EventCommandService.setCompleted`를 사용해 저장, 알림·알람, 동기화와 Apple
  위젯 갱신을 기존 Todo 경로와 동일하게 처리한다.
- 월간의 일정 바를 짧게 누르면 실제 누른 날짜가 즉시 선택된다. 여러 날짜에
  걸친 일정도 바 내부 좌표로 날짜를 판별한다.
- #42 일정 바 길게 누르기는 날짜 범위 선택보다 먼저 시작하며, 상하 연속 달력
  바깥 범위 선택 상태까지 취소해 실제 날짜 이동 드래그가 막히지 않게 했다.
- #41 라이트 모드 노란색 대비 구현은 전부 제거하고 이슈를 보류했다.
- #44는 macOS 월·주·일 PageView의 휠 중복 소비를 막고 마우스 입력을 순서형
  한 단계 큐로 처리한다. 트랙패드와 상하 연속 월간 스크롤은 유지한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 232개 통과
  - `./tool/flutter.sh build macos --debug --no-pub` 통과
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` 통과
- 이번 보정은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-08-22 #14·#42·#44 및 Apple UI 후속 보정

- #44 macOS 목록형 월·주·일 이동은 작은 마우스 휠 입력도 한 틱으로 인정한다.
  기존처럼 각 페이지 애니메이션 종료를 순차 대기하지 않고 마지막 누적 목표
  페이지로 즉시 재지정해, 연속 휠 입력이 느리게 밀려 처리되는 현상을 줄였다.
- #42 월간 일정 이동은 실제 primary mouse button 길게 누르기를 지원한다. 일정
  막대 위에서도 날짜 드롭 영역이 최상단에 활성화되어 macOS에서 일정이 있는
  날짜와 빈 날짜 모두로 이동할 수 있다.
- #14 완료 일정은 라이트·다크 모드별 `onSurface` 고대비 회색과 굵은 이중
  취소선을 공통 사용한다. 빠른 보기, 월·주·일 캘린더, 상세, 검색, Apple
  위젯이 같은 완료 상태를 표시하도록 했다.
- 주간·일간의 날짜 헤더와 목록형 날짜 패널에서는 공휴일 붉은 배경을 제거했다.
  일요일·토요일·공휴일의 글자색과 일정 자체 분류색은 유지한다.
- Apple 플랫폼 설정에 `Siri 단축어 설정`을 추가했다. `시그널` 단축어에
  `텍스트 받아쓰기`와 `Daily Signal` 동작을 연결하는 순서를 안내하고 단축어
  생성 화면을 연다.
- Apple 위젯은 하드코딩된 밝은 배경 대신 iOS `systemBackground`, macOS
  `windowBackgroundColor`와 시스템 primary/secondary 색상을 사용해 다크 모드를
  따른다.
- 오늘 일정 위젯과 잠금 화면 직사각형 오늘 일정 위젯의 일정 왼쪽에 Todo
  체크박스를 표시한다. 완료·미완료 변경은 체크박스의 AppIntent 버튼에서만
  실행되며 일정 텍스트 자체는 상태를 변경하지 않는다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 236개 통과
  - `./tool/flutter.sh build macos --debug --no-pub` 통과
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` 통과
- 최신 테스트 앱 설치:
  - macOS `/Users/kimhwi/Applications/Daily Test.app`, 버전/빌드
    `3.1.0 / 3.1.0`, `com.littlebit0.daily.test`, Apple Development 서명 확인
  - iPhone 17 시뮬레이터 `BF524643-403E-4212-ACB7-621E11279532`, 버전/빌드
    `3.1.0 / 3.1.0`, `com.littlebit0.daily` 업데이트 설치 및 실행
  - iOS 업데이트 뒤 `daily.sqlite`, 앱 설정 plist와 기존 일정 레코드가 새 데이터
    컨테이너에 존재함을 확인했다.
- Android와 Windows 플랫폼 구현 파일은 수정하지 않았다. 이번 변경은 아직
  커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-08-22 #14·#42 및 Apple 위젯·Signal 최종 보정

- #14 주간·일간의 목록형 일정과 스케줄형 종일·시간 일정은 완료되면 분류
  색상을 사용하지 않는다. 라이트·다크 모드별 전용 완료 배경색·강조색·전경색과
  굵은 이중 취소선을 함께 적용한다.
- #42 날짜 이동은 월간 일정 막대뿐 아니라 다음 위치에서도 길게 누른 뒤 원하는
  날짜에 놓는 방식으로 지원한다.
  - 월간에서 날짜를 선택해 연 날짜별 일정 목록과 macOS 오른쪽 하루 목록
  - 주간·일간 목록형 일정
  - 주간·일간 스케줄형 종일 일정과 시간 일정
  - 일간 스케줄처럼 화면에 다른 날짜가 없는 경우에는 월 달력 날짜 선택층
- 날짜 이동은 시간과 기간을 유지하며, 반복 일정은 기존 반복 범위 선택 규칙을
  사용한다. 이동 전후 날짜의 수동 일정 순서도 함께 갱신한다.
- Apple 위젯은 명시적으로 시스템 라이트·다크 상태를 읽어 밝은 모드에서는 흰색,
  다크 모드에서는 검은색 배경을 사용한다.
- 위젯 Todo 체크는 공유 스냅샷을 즉시 갱신해 화면에 바로 반영하고 작업 대기열에
  기록한다. 앱이 실행 중이면 iOS Darwin 알림 또는 macOS 분산 알림으로 Flutter에
  즉시 전달해 실제 일정 완료 상태와 위젯 스냅샷을 다시 동기화한다.
- `Daily Signal`은 사용자가 별도 단축어를 조립하지 않아도 App Shortcut으로
  자동 노출된다. 설정 안내에는 실행 문구와 사용 예시, 단축어 앱에서 등록 상태를
  확인하는 버튼을 제공한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 240개 통과
  - 완료 색상·날짜 목록 이동·스케줄 이동·Apple 위젯·Signal 집중 테스트 통과
  - `./tool/flutter.sh build macos --debug --no-pub` 통과
  - `./tool/flutter.sh build ios --simulator --debug --no-pub` 통과
  - `git diff --check` 통과
- 최신 테스트 앱 업데이트 및 실행:
  - macOS `/Users/kimhwi/Applications/Daily Test.app`, `3.1.0 / 3.1.0`,
    `com.littlebit0.daily.test`; `DailyMacWidgets.appex` 포함 및 시스템 등록 확인
  - iPhone 17 시뮬레이터 `BF524643-403E-4212-ACB7-621E11279532`,
    `3.1.0 / 3.1.0`, `com.littlebit0.daily`; 기존 앱에 덮어 설치하고 실행
  - iOS 설치 후 기존 `daily.sqlite`와 일정 레코드가 새 컨테이너로 이전된 것을
    확인했다.
- Android와 Windows 플랫폼 구현 파일은 수정하지 않았다. 이번 최종 보정도 아직
  커밋하거나 원격 저장소에 푸시하지 않았다.
# 2026-08-25 Siri 시그널 단축어 직접 추가

- `Siri 단축어 설정`은 App Shortcut 자동 등록 안내가 아니라 완성된
  개인 단축어 `시그널`의 Apple `단축어 추가` 화면을 직접 연다.
- `시그널`은 `텍스트 받아쓰기` → `Daily Signal`의 `Signal phrase`로
  받아쓰기 결과를 전달하도록 구성했다.
- 공유 링크:
  `https://www.icloud.com/shortcuts/d38300f25eca434db08375c9924b4e18`
- iCloud 공유 페이지 URL을 비공개 `shortcuts://import-shortcut`에 넣으면
  최신 macOS에서 유효하지 않은 URL 오류가 발생한다. 이 방식은 제거했다.
- 설정 버튼은 Apple이 지원하는 iCloud 공유 페이지를 직접 연다. 사용자는
  해당 화면의 `단축어 받기/추가`를 눌러 설치한다.
- 수동 제작 안내와 “앱 설치와 함께 자동 등록”이라는 잘못된 설명창은
  제거했다. Apple의 최종 `단축어 추가` 승인은 사용자가 누른다.
- 검증: `flutter analyze --no-pub` 통과, `test/widget_test.dart` 및
  `test/core/localization/app_localizations_test.dart` 65개 통과.

### 2026-08-25 Apple 위젯 Todo·다크 모드 및 macOS 하루 패널 드래그 보정

- 위젯 Todo 동작의 네이티브 `DailyToggleTodoIntent`를 모듈에 노출되는
  `AppIntent`로 수정했다. 위젯 체크 시 공유 작업 큐와 스냅샷을 즉시 갱신하고,
  앱이 작업을 실제 데이터베이스에 반영한 뒤 위젯 스냅샷을 다시 생성한다.
  App Group 접근 실패는 성공으로 삼키지 않고 오류로 처리한다.
- 위젯 스냅샷의 `themeMode`를 실제 렌더링에 사용한다. `자동`은 macOS/iOS의
  현재 `colorScheme`을 따르고, `화이트`와 `다크`는 각 위젯의 전체 배경과
  텍스트 색상 체계를 명시적으로 고정한다.
- Debug 위젯 표시 이름은 `Daily Test Widgets`, Release/Profile은
  `Daily Widgets`로 분리해 테스트 위젯과 App Store 위젯을 구분한다.
- macOS 월간 화면의 오른쪽 하루 패널은 드래그 중에도 목록 상태를 그대로
  유지한다. 하루 패널 내부 드래그는 해당 날짜 일정의 수동 순서를 변경하고,
  패널에서 왼쪽 월 달력 날짜로 드래그하면 시간과 기간을 유지해 날짜를
  이동한다. 같은 드래그에서 두 동작을 날짜/드롭 위치에 따라 구분한다.
- iPhone 17 시뮬레이터의 실제 홈 화면에 `Daily Test` 오늘 일정 위젯을
  추가해 다음을 검증했다.
  - 시스템 다크 모드에서 검은 배경과 밝은 텍스트가 자동 적용됨
  - Todo 체크박스 탭 직후 위젯 완료 표시가 갱신됨
  - 공유 작업 큐가 Flutter로 전달되고 실제 일정 데이터베이스 반영 후 비워짐
  - 검증용 임시 일정은 삭제했으며 작업 큐는 `[]` 상태임
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 241개 통과
  - macOS Debug 및 iOS Simulator Debug 빌드 통과
  - 양쪽 위젯 확장의 AppIntent metadata와 App Group entitlement 확인
- 최신 테스트 앱:
  - macOS `/Users/kimhwi/Applications/Daily Test.app` 업데이트 설치 및 실행
  - iPhone 17 시뮬레이터 `BF524643-403E-4212-ACB7-621E11279532`에 업데이트
    설치하고 위젯 실동작 검증
- Android와 Windows 구현 파일은 수정하지 않았다. 이번 변경은 아직 커밋하거나
  원격 저장소에 푸시하지 않았다.

### 2026-08-25 Apple 위젯 라이트·다크 반복 전환 보정

- 위젯 콘텐츠 영역의 `.background`와 WidgetKit의 `containerBackground`가
  동시에 그려져 다크 모드에서 안쪽 여백만 별도의 검은 사각형으로 남는 원인을
  확인했다. 콘텐츠 배경은 제거하고 전체 위젯 컨테이너 배경 하나만 사용한다.
- 후속 macOS 실기기 조사에서 위젯 종류별 타임라인 새로고침이 운영체제에 의해
  독립적으로 처리되고, 빠른 테마 왕복 시 여러 갱신이 경합할 수 있음을
  확인했다. 앱 테마 변경 갱신은 짧게 병합해 마지막 선택만 반영하고, 렌더링
  identity에는 스냅샷 테마와 실제 적용 색상 체계를 함께 사용한다.
- iOS와 macOS가 스냅샷을 갱신할 때 오늘 일정·주월간·D-day 세 위젯 kind를
  각각 명시적으로 reload하도록 변경했다.
- iPhone 17 시뮬레이터 홈 화면에서 라이트→다크 전환을 6회 반복 캡처했다.
  모든 전환에서 배경과 텍스트가 함께 변경됐고 기존 안쪽 사각형과 부분 색상
  잔상이 재현되지 않았다.
- 검증:
  - 관련 Apple 위젯 테스트 10개 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 전체 Flutter 테스트 241개 통과
  - macOS Debug 및 iOS Simulator Debug 빌드 통과
  - macOS `/Users/kimhwi/Applications/Daily Test.app`과 iPhone 17 시뮬레이터에
    최신 테스트 빌드 업데이트 설치
- Android와 Windows는 수정하지 않았으며 커밋·푸시는 아직 진행하지 않았다.

### 2026-08-25 macOS 위젯 혼합 테마 최종 확인

- macOS에서 같은 Daily 위젯 중 일부만 이전 색상으로 남을 수 있던 경로를
  조사해 앱 테마 무시, 빠른 갱신 경합, 테스트 위젯 확장 중복 등록을 함께
  정리했다.
- 모든 Daily 위젯은 `자동`에서 시스템 `@Environment(\.colorScheme)`을
  따르고, `화이트`와 `다크`에서는 스냅샷의 `themeMode`에 따라 전체 위젯을
  명시적으로 같은 색상 체계로 렌더링한다.
- 앱에서 테마를 빠르게 연속 변경하면 400ms 동안 요청을 병합하고 마지막
  선택에 대해서만 위젯 스냅샷과 타임라인을 갱신한다.
- `/Users/kimhwi/Applications/Daily Test.app`을 최신 빌드로 교체하고 이전
  테스트 위젯 확장 중복 등록을 제거한 뒤 하나만 다시 등록했다. App Store의
  `/Applications/Daily.app`은 변경하지 않았다.
- macOS 실기기에서 소형·대형 오늘 일정 위젯과 중형 주간 위젯을 유지한 채
  `다크`, `화이트`, `자동`을 실제 GUI로 확인했다. 수동 모드에서는 세 Daily
  위젯이 모두 지정 색상으로 함께 변경됐고, `자동`에서는 현재 macOS 다크
  외형을 세 위젯이 함께 따랐다.
- 검증 후 앱 설정과 공유 위젯 스냅샷의 `themeMode`가 모두 `system`임을
  확인했다. Daily Test의 앱 테마는 `시스템 설정에 따름`으로 남겨 두었다.
- Android와 Windows는 수정하지 않았으며 커밋·푸시는 진행하지 않았다.

### 2026-08-25 DailyCalendar 3.2.0 릴리스 준비

- 앱 표시 버전과 빌드를 `3.2.0 (3.2.0)`으로 승격했다.
- README의 버전, 다운로드 파일, 저장소 주소와 기능 설명을 현재 구현에 맞게
  갱신하고 공식 저장소 주소를 `littlebit0/DailyCalendar`로 통일했다.
- `docs/RELEASE_NOTES_3.2.0.md`에 3.1.0 이후 Todo 통합, 안전 마이그레이션,
  일정 날짜 이동·수동 순서, 분류·공휴일 설정, 복원 안전성, Siri와 Apple 위젯
  개선 사항을 정리했다.
- `v3.2.0` 태그 푸시 시 Apple 전용 릴리스 워크플로가 iOS unsigned IPA와
  macOS unsigned DMG를 만들고 GitHub Release에 게시하도록 구성했다.
- Android 서명 비밀값이 없어 자동 태그 릴리스가 실패하던 전체 플랫폼
  워크플로는 수동 실행으로 유지한다. Android와 Windows 구현 파일은 이번
  릴리스 준비에서 수정하지 않았다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 242개 통과
  - macOS Debug와 iOS Simulator Debug 빌드 통과
  - iOS/macOS 앱과 위젯의 표시 버전·빌드가 모두 `3.2.0 / 3.2.0`임을 확인
### 2026-08-25 실시간 익명 사용성 분석 서버 배포

- Ubuntu `littlebit@100.113.124.14`에 독립 Python 분석 수신기를 배포했다.
  - 사용자 systemd 서비스: `daily-analytics.service`
  - 실행 파일: `~/.local/lib/daily-analytics/analytics_receiver.py`
  - 집계 저장소: `/mnt/storage/daily-analytics` (1.8TB HDD `/dev/sda1`)
  - `loginctl` linger를 활성화해 로그아웃 및 재부팅 뒤에도 서비스를 시작한다.
- Tailscale Funnel 공개 HTTPS를 연결했다.
  - 수신: `https://littlebit.tail6514a4.ts.net/v1/events`
  - 상태: `https://littlebit.tail6514a4.ts.net/health`
- 실제 외부 POST가 서버 디스크의 일별 집계 파일에 즉시 반영되는 것을 확인했다.
  원본 요청, 세션 ID와 이벤트 ID는 집계 파일에 저장되지 않는다.
- `3.2.0 (3.2.0)` iOS/macOS App Store 서명 산출물을 위 엔드포인트가 포함된
  상태로 다시 생성했다.
  - `dist/transporter-upload/3.2.0/ios/Daily-iOS-AppStore-3.2.0-build-3.2.0.ipa`
  - `dist/transporter-upload/3.2.0/macos/Daily-macOS-AppStore-3.2.0-build-3.2.0.pkg`
- 익명 사용성 분석은 계속 기본 비활성화이며 사용자가 설정에서 명시적으로
  허용한 경우에만 전송한다.

### 2026-08-25 macOS 이동·인증 버그 제보·iOS 설정 가독성

- macOS 주간/일간 트랙패드 이동은 기존 구현이 이미 동작하고 있었다. 후속
  작업에서 중복 추가했던 `PointerPanZoom` 처리 때문에 좌우 방향이 반전되어,
  추가 처리기와 누적 판정 코드를 전부 제거하고 기존 단일 스크롤 경로로
  복원했다. 목록·스케줄의 원래 이동 방식과 스케줄 세로 시간 이동을 유지한다.
- 일정 상세 및 macOS 우측 하루 보기의 날짜 헤더에서 공휴일 색상 강조 기능
  자체를 제거했다. 공휴일인 날짜도 일반 날짜와 같은 텍스트 헤더로 표시한다.
- Google로 Daily를 이용 중인 사용자만 설정의 버그 제보 기능을 사용할 수
  있도록 구현했다.
  - 앱은 자동 로그인 창을 띄우지 않고 기존 Google 인증을 조용히 확인한다.
  - 서버는 Google 토큰의 서명·이메일 인증 여부를 확인한 뒤 사용자의
    `littlebit0/DailyCalendar` 저장소에 이슈를 생성한다.
  - 이메일은 공개 GitHub 이슈 본문에 넣지 않고 Ubuntu HDD의
    `/mnt/storage/daily-analytics/bug-report-contacts`에만 비공개로 보관한다.
  - 서버의 GitHub 토큰은 `littlebit0/DailyCalendar` 단일 저장소의 Issues
    쓰기 권한만 가진 fine-grained PAT이며, Ubuntu의
    `~/.config/daily/bug-report.env`에 권한 `0600`으로 저장했다. 최초 생성
    토큰은 노출 가능성을 확인해 사용 전에 폐기했고, 새 토큰을 재생성해
    적용했다. 토큰 값은 저장소에 기록하지 않았다.
- iOS 설정 설명은 기기 가로폭, 글자 크기, 언어를 기준으로 단어 경계에서
  반응형 줄바꿈되도록 수정했다. 긴 단일 문자열은 화면 밖으로 넘치지 않도록
  예외적으로 글자 단위 줄바꿈을 허용한다.
- 서버 확인:
  - `daily-analytics.service` 활성 상태
  - `https://littlebit.tail6514a4.ts.net/health` 정상
  - GitHub 인증 사용자 `littlebit0`, 대상 저장소 `littlebit0/DailyCalendar`
  - 잘못된 Google 토큰은 `401 invalid_google_token`으로 거부
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 전체 Flutter 테스트 243개 통과
  - 분석/버그 제보 서버 테스트 4개 통과
  - macOS Debug 및 iOS Simulator Debug 빌드 통과
  - `/Users/kimhwi/Applications/Daily Test.app`과 iPhone 17 시뮬레이터에
    최신 빌드 업데이트 및 실행 확인
- App Store의 `/Applications/Daily.app`은 변경하지 않았다. Android와
  Windows 구현 파일도 수정하지 않았다.

### 2026-08-26 DailyCalendar 3.2.1 릴리스

- 앱과 Apple 위젯의 표시 버전·빌드를 `3.2.1 (3.2.1)`로 승격했다.
- macOS 월간 좌우, 주간·일간 목록/스케줄의 트랙패드 이동이 멈춘 원인은
  공통 `PageView`에 적용된 `NeverScrollableScrollPhysics`였다.
- `_ResponsiveMonthPagePhysics`를 복원해 macOS 네이티브 트랙패드
  `PointerPanZoom` 이동을 다시 활성화했다. 마우스 휠의 개별 페이지 이동에는
  기존 단일 포인터 신호 경로만 사용하며 중복 트랙패드 처리기는 추가하지 않았다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 전체 Flutter 테스트 243개 통과
  - 분석·버그 제보 서버 테스트 4개 통과
  - 월간 좌우, 주간·일간 목록/스케줄의 `PointerPanZoom` 왕복 테스트 통과
- 사용자의 지시에 따라 GUI 실행과 수동 동작 테스트는 진행하지 않았다.
- GitHub Release에는 unsigned IPA/DMG만 공개하고, App Store Connect용 서명
  IPA/PKG는 `dist/transporter-upload/3.2.1`에만 생성한다.

### 2026-08-26 Apple 통일 UI와 분석 동의 온보딩

- Daily의 기존 캘린더 동작을 유지하면서 Apple 플랫폼과 어울리는 공통 화면
  체계를 추가했다.
  - 공통 페이지 배경, 내비게이션 바, 그룹형 설정 섹션, 아이콘 행, 주요·보조
    버튼, 안내 문구, 온보딩 프레임을 `lib/core/theme/daily_ui.dart`에 모았다.
  - 카드 중첩과 과도한 장식을 피하고 iOS/macOS의 그룹형 정보 구조, 명확한
    계층, 라이트·다크 대응을 공통 적용했다.
- 새 사용자 온보딩 순서는 Daily 소개 → 익명 사용성 분석 선택 → Siri 단축어
  설정(Apple 플랫폼) → 알림·알람 권한 → Apple/Google/로컬 시작이다.
  - 분석은 기본 비활성화이며 사용자가 명시적으로 동의한 뒤에만 전송한다.
  - 거절 선택도 저장해 다음 실행 때 다시 강요하지 않는다.
  - 기존 사용자에게도 아직 선택 기록이 없을 때 한 번만 분석 동의 화면을
    표시한다.
  - 앱 시작만으로 알림·AlarmKit 권한을 자동 요청하지 않고 사용자가 온보딩의
    권한 버튼을 누른 뒤 요청한다.
  - Siri 설정은 검증된 `시그널` iCloud 단축어 추가 화면을 연다.
- 다음 화면을 새 공통 UI로 정리했다.
  - 빠른 보기: 분류별 Todo 카드, 반응형 정보 밀도, 완료 상태와 빈 상태
  - 설정: 계정, 알림, 화면·달력, 분류, 개인정보·잠금, AI, 앱 정보 화면 분리
  - Siri 작업 기록과 캘린더 가져오기
  - 검색, 필터, 일정 추가·수정, Signal/AI 패널, 버그 제보
- 월간·주간·일간 캘린더 본문, macOS 오른쪽 하루 보기와 기존 일정 동작은 이번
  디자인 작업에서 의도적으로 교체하지 않았다.
- 한국어, 영어, 일본어, 중국어 번체의 이번 신규·변경 UI 문구를 모두 추가했고
  정적 누락 검사에서 네 언어 모두 누락 0개를 확인했다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 248개 통과
  - `./tool/flutter.sh build ios --simulator --no-pub` 통과
  - `./tool/flutter.sh build macos --no-pub` 통과
  - macOS 빌드에는 GoogleSignIn 헤더, Flutter 코드 에셋 이름과 기존 Siri
    deprecated API 경고가 남아 있지만 빌드는 정상 완료된다.
- 최초 구현 검증에서는 앱 설치·실행과 GUI 수동 테스트를 수행하지 않았다.
  이후 사용자의 명시적인 재설치 요청에 따라 다음 테스트 앱만 최신 빌드로
  교체했고 자동 실행이나 GUI 조작은 하지 않았다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.2.1 (3.2.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    표시 이름 `Daily Test`, `com.littlebit0.daily`, `3.2.1 (3.2.1)`
  - App Store의 `/Applications/Daily.app`은 변경하지 않았다.
- 다음 수동 확인은 온보딩 각 단계, 동의/거절 재실행, Siri 단축어 추가,
  Apple·Google·로컬 진입, 빠른 보기 Todo, 설정 각 하위 화면, 검색·필터,
  일정 편집, Signal 패널, 버그 제보의 라이트·다크 및 큰 글자 상태다.
- 변경 대부분은 공유 Flutter UI이므로 Android/Windows에도 컴파일상 반영될 수
  있다. 이번 작업에서는 Android/Windows 실기기·빌드 검증을 하지 않았으므로
  다음 플랫폼 작업자가 레이아웃, Apple 전용 온보딩 단계 제외 여부와 권한
  흐름을 별도로 확인해야 한다.
- 이번 변경은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-08-26 온보딩 진입·계정 버튼·알림 테스트·달력 버튼·Todo 보정

- iOS 온보딩에서 Siri/권한 단계를 완료한 뒤 로그인 단계로 이동해도 이전
  단계의 busy 상태가 남아 Apple·Google·로컬 버튼이 모두 비활성화되던 원인을
  수정했다. 단계 전환 시 busy 상태와 안내 메시지를 함께 초기화한다.
- 계정 설정의 Apple 로그인/연동 해지, Google 연결·백업·복원·취소·연동 해지,
  로그아웃, 계정 삭제/로컬 초기화 버튼을 동일한 높이·모서리·아이콘·로딩·
  파괴적 색상 규칙으로 통일했다.
- 사용자용 알림 기능은 유지하면서 `알림 테스트` 기능만 제거했다.
  - 테스트 알림 UI, 전송 API, 전용 notification ID와 다국어 문구를 삭제했다.
  - 기본 일정 알림, 아침 브리핑, D-day, 권한 처리와 시스템 알림 설정 이동은
    그대로 유지한다.
- 빠른 보기·주간·월간·일간에서 공유하는 상단 도구막대, iOS 하단 주/월/일 및
  빠른 보기/달력/AI 슬라이더, 스케줄 종일 일정 버튼, 검색·필터·AI 보조 버튼에
  공통 `DailyIconAction`과 선택 색상 규칙을 적용했다. 달력 셀, 일정 카드,
  배치, 제스처와 화면 전환 로직은 변경하지 않았다.
- Todo 완료는 제목이 아니라 일정 ID로만 처리함을 회귀 테스트로 고정했다.
  반복 일정 발생분은 원본 ID를 공유하던 구조 때문에 한 발생분을 체크하면
  나머지 반복분도 함께 완료되는 문제가 있었다. 선택한 날짜를 원본 반복에서
  제외하고 그 발생분만 고유 ID의 독립 일정으로 원자 저장해 완료 상태를
  분리한다. 원본 반복 일정과 분리된 발생분은 모두 v2 이벤트 동기화 큐에
  올린다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 250개 통과
  - iOS Simulator Debug 빌드 통과
  - macOS Debug 빌드 통과
  - macOS 빌드의 GoogleSignIn umbrella header 및 기존 Siri deprecated API
    경고는 남아 있으나 빌드는 정상 완료된다.
- 사용자의 별도 요청이 없으므로 이번 검증에서는 앱 설치·실행과 GUI 조작을
  하지 않았다. 커밋과 푸시도 아직 진행하지 않았다.

### 2026-08-26 DailyCalendar 3.3.0 릴리스 준비

- 앱과 Apple 위젯의 표시 버전·빌드를 `3.3.0 (3.3.0)`으로 승격했다.
- README, Apple 빌드·개인정보 문서, GitHub Actions 릴리스 설정과
  `docs/RELEASE_NOTES_3.3.0.md`를 3.3.0 기준으로 갱신했다.
- 이번 릴리스에는 단계형 온보딩과 분석 동의, Apple 스타일 공통 UI, 계정 작업
  버튼 통일, 개발용 알림 테스트 제거, 반복 일정 Todo 완료 분리, 캘린더 조작부
  아이콘·외곽선 정리가 포함된다.
- 공개 GitHub Release에는 검증용 unsigned IPA와 DMG만 올린다. App Store
  Connect 제출용 서명 IPA/PKG는 로컬 `dist/transporter-upload/3.3.0`에만
  생성하고 Git에는 포함하지 않는다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 250개 통과
  - `python3 -m unittest test/tool/analytics_receiver_test.py` 전체 4개 통과
- 사용자의 별도 실행 요청이 없으므로 3.3.0 앱을 설치하거나 GUI로 실행하지
  않았다.

### 2026-08-26 DailyCalendar 3.3.1 분석 전송 보정

- 앱과 Apple 위젯의 표시 버전·빌드를 `3.3.1 (3.3.1)`로 승격했다.
- 3.3.0 서명 산출물에는 버그 제보 주소만 포함되고 익명 사용성 분석 주소가
  누락된 사실을 바이너리 문자열 검사로 확인했다.
- 같은 누락이 반복되지 않도록 Release 모드에서는 운영 HTTPS 분석 주소를
  기본값으로 사용하고, Debug/Test에서는 명시적인 주소가 없으면 계속 전송하지
  않도록 수정했다. 분석 수집은 기존과 동일하게 사용자 동의 전에는 꺼져 있다.
- README, Apple 빌드·개인정보·분석 배포 문서와 GitHub 릴리스 워크플로를
  3.3.1 기준으로 갱신하고 `docs/RELEASE_NOTES_3.3.1.md`를 추가했다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 250개 통과
  - `python3 -m unittest test/tool/analytics_receiver_test.py` 전체 4개 통과

### 2026-08-27 Android/Windows 초기 온보딩 분석 동의 반복 수정

- 신규 설치 온보딩에서 익명 분석 선택이 저장될 때 최상위 `MaterialApp` key까지
  함께 바뀌어 진행 중인 `WelcomePage`가 재생성되고 단계 상태가 초기화되던 문제를
  수정했다.
- 온보딩이 끝나기 전에는 앱 shell key를 고정하고, 이미 온보딩을 마친 기존
  사용자의 일회성 분석 동의 게이트에서만 동의 완료 상태에 따라 shell을
  전환한다. 따라서 소개 → 익명 분석 선택 → 알림·알람 권한 → 계정 선택 순서가
  Android와 Windows에서 한 번씩만 진행된다.
- Android/Windows 각각에서 알림 초기화가 대기 중인 상태와 앱 inactive/resumed
  복귀를 재현하는 위젯 회귀 테스트를 추가했다. Apple 온보딩의 Siri 추가 단계와
  기존 사용자 분석 동의 게이트는 변경하지 않았으며, 공유 shell 변경이므로 다음
  Apple 작업 시 신규 설치 온보딩 순서만 수동 확인한다.
- 검증:
  - 온보딩 및 기존 사용자 분석 동의 집중 위젯 테스트 4개 통과
  - `./tool/flutter.ps1 analyze --no-pub` 통과
  - `./tool/flutter.ps1 test --no-pub -r compact` 전체 267개 통과
  - `git diff --check -- lib/app/daily_app.dart test/widget_test.dart` 통과

### 2026-08-27 Windows 설정 눌림 애니메이션 및 스크롤 보정

- Windows 주간·일간 스케줄 시간축의 마우스 휠 이동은 월간 상하 스크롤과 같은
  공용 완화 컨트롤러를 사용하도록 맞췄다.
- Windows 설정 저장 중에도 컨트롤이 즉시 움직이도록 화면에는 pending 설정을
  먼저 반영하고, 전체 설정 저장은 직렬화했다. 저장 실패 시 마지막 확정값으로
  되돌리고 이전 저장이 뒤늦게 최신 선택을 덮어쓰지 않도록 revision을 관리한다.
- 첫 보정 뒤에도 사용자에게 버튼 눌림이 보이지 않았던 원인은 공용
  `_ThreeWayCapsule`이 선택값 이동만 애니메이션하고 실제 pointer-down 상태를
  갖지 않았기 때문이었다.
  - pointer-down 즉시 선택 pill을 미리 이동하고 0.93배로 축소한다.
  - 눌림 75ms, 복귀 160ms, 선택 이동 220ms를 사용한다.
  - 각 선택지에 Material InkWell 상태 레이어와 글자 색·굵기 전환을 적용한다.
  - 키보드 highlight와 선택/상호배타 semantics를 함께 제공한다.
- 모든 설정 `SwitchListTile`은 공용 눌림 래퍼를 사용한다. 눌렀을 때 타일을
  0.985배로 축소하고 배경·switch overlay를 강조하며, 둥근 Material clip으로
  잉크가 타일 밖으로 번지지 않게 했다.
- 버튼 위에서 세로 스크롤을 시작할 때 수평 드래그가 잘못 선택되는 문제를
  막기 위해 touch slop 이후 실제 이동 축을 판별한다. 수평 이동만 캡슐 선택으로
  처리하고 세로 이동은 눌림을 취소한다. 우·중클릭은 눌림으로 처리하지 않으며,
  화면 전환 중 pointer-up에도 dispose된 State를 갱신하지 않는다.
- 검증:
  - 16ms/50ms 실제 렌더 배율과 선택 위치를 검사하는 Windows 설정 위젯 테스트 통과
  - 같은 선택 재클릭, 수평 드래그, 세로 스크롤 취소, 우클릭 무반응, switch
    눌림·취소, dispose 중 pointer-up, semantics 선택 상태 회귀 테스트 통과
  - `./tool/flutter.ps1 analyze` 통과
  - `./tool/flutter.ps1 test` 전체 272개 통과
  - Profile/AOT 테스트판을
    `%LOCALAPPDATA%\Programs\DailyCalendar Test\DailyCalendar Test.exe`에 재설치하고
    실행했다. `app.so`가 있고 Debug `kernel_blob.bin`은 없으며 `IsDebug=false`이다.
  - GUI에서 테마 캡슐과 음력 switch의 눌림 강조를 확인하고 원래 값(자동/끔)으로
    복구했다. 앱은 `화면 및 달력` 설정 화면에 열어 두었다.
  - 배포판 `C:\Program Files\Daily\DailyCalendar.exe`의 SHA-256은
    `7F986A716C0D6F7E7A980CA00055AD0B1E56C2B3D2BA8A457EE1DFAB0D0B58A6`로 유지됐다.
- 이번 작업은 커밋하거나 푸시하지 않았다.

### 2026-08-27 Windows 설정 프레임 정지 원인 및 저장 보정

- 설정 버튼 애니메이션이 빠진 것처럼 보였던 직접 원인은 Windows
  `shared_preferences_windows 2.4.1`이 각 setter마다 약 54KB의 전체 JSON을 UI
  isolate에서 동기 재작성하면서 중간 프레임을 막은 것이었다. 수정 전 수집된 느린
  프레임 16건은 중앙값 397.5ms, 평균 424.8ms, 최대 558ms였다.
- `SettingsRepository.save`를 전체 약 40개 키 재저장에서 실제 변경 키만 쓰도록
  바꿨다. 일반 설정 1개는 동기 전체 파일 쓰기가 pending 상태에 따라 2회 또는
  3회로 줄었다. 이전 reminder/text-size 마이그레이션과 privacy legacy key 정리는
  유지했다.
- Windows 설정 화면은 값을 즉시 화면에 반영한 뒤 눌림·토글 모션이 끝나는
  240ms 후 저장한다. 페이지별 저장 tail, 저장소 전역 mutation queue,
  generation과 `changedFrom` 기반 필드 병합으로 빠른 연속 입력·외부 변경·reset·
  Google Drive 복원이 서로 덮어쓰지 않게 했다. 성공한 각 저장은 백업을 예약하고,
  앱 잠금 해제/방식 변경은 설정 저장 후 PIN을 삭제한다.
- reset에서 누락됐던 기본 reminder 목록, theme, month navigation, language 키를
  함께 지운다. 원격 설정 복원은 같은 mutation queue 안에서 pending/revision/
  generation을 원자적으로 확인한다.
- 검증:
  - `flutter analyze` 통과
  - 전체 테스트 `flutter test --concurrency=1` 288개 통과
  - Profile/AOT 테스트판에서 약 54KB 설정 파일과 200개 분석 큐를 유지하고 음력
    토글을 6회 측정했다. revision은 34→40으로 정확히 증가했고 원래 값 `false`,
    분석 동의 `true`가 유지됐다.
  - 같은 측정 구간의 `slow_interaction_detected`는 0건이었다. 기존 397.5ms 중앙값,
    558ms 최대 정지는 재현되지 않았고 클릭 직후 눌림·토글 중간 프레임이 실제
    화면에 표시됐다.
  - 배포판 `C:\Program Files\Daily\DailyCalendar.exe`의 SHA-256은
    `7F986A716C0D6F7E7A980CA00055AD0B1E56C2B3D2BA8A457EE1DFAB0D0B58A6`로 유지됐다.
- Profile 테스트판은 `화면 및 달력` 설정 화면에 열어 두었고 음력 설정은 측정 전
  값인 꺼짐으로 복구했다. 이번 작업은 커밋하거나 푸시하지 않았다.
### 2026-09-01 GitHub 이슈 #53~#60 처리

- 사용자 지시에 따라 `not planned`인 #57과 Android 전용으로 남겨 둔 #36은
  제외하고, Apple 공통 범위의 #53~#60을 순서대로 점검·수정했다.
- #53: 현재 주·월·일 캘린더 디자인이 기존 동작을 유지하는지 코드와 테스트로
  확인했으며 추가 변경 없이 GitHub 이슈를 완료 처리했다.
- #54: 분류 재정렬의 Flutter 하향 이동 인덱스를 보정하고, 화면 상태를 먼저
  갱신한 뒤 저장·설정 백업을 직렬화했다. 최신 저장만 실패 시 롤백한다.
  후속 요청으로 iOS 월간 날짜 상세보기를 달력과 같은 Scaffold의 비모달
  시트로 변경해 상세 목록의 일정을 실제 월간 날짜 셀까지 드래그할 수 있게
  했다. macOS/iOS 공용 드래그 피드백은 최상위 오버레이에서 잡고 있는 일정
  카드 자체를 표시한다.
- #55: 날짜 상세 목록에서 바꾼 수동 일정 순서를 앱 설정에 즉시 반영해 월간
  캘린더도 같은 순서를 사용하도록 통합했다. 저장 실패 시 최신 상태만
  롤백한다.
- #56: 분리되어 있던 `첫 화면`과 `기본 보기` 설정을 하나의 4단 선택기
  `빠른 보기 / 주 / 월 / 일`로 통합했다. 내부 저장값은 기존 버전 및 Google
  Drive 설정 백업과 호환되도록 유지하며, 앱의 완전한 새 시작에만 적용하고
  백그라운드 복귀 화면은 유지한다.
- #58: 앱과 Apple 위젯의 완료 일정 표시를 이중 취소선에서 중앙 단일
  취소선으로 변경했다.
- #59: 완료 여부와 관계없이 제목뿐 아니라 일정의 테두리·강조선·배경에도
  저장된 분류 색상을 유지한다. 완료 상태는 테마 대비 취소선으로만 표시하며
  앱 전체와 Apple 위젯의 분류 정체성을 보존한다.
- #60: 월간·주간·일간의 목록 및 스케줄 일정 드래그 상태를 최상위 달력에
  전달한다. 드래그를 화면 가장자리에 700ms 유지하면 현재 보기 방향에 맞춰
  이전·다음 기간으로 이동하며 계속 유지하면 여러 기간을 반복 이동한다.
  포인터 종료·취소 시 자동 이동 상태를 확실히 정리한다.
- #60 통합 테스트는 일정을 오른쪽 가장자리에 유지해 두 주를 연속 이동한 뒤
  다음다음 주 날짜에 놓고, 날짜만 바뀌며 시작 시간과 기간이 보존되어
  저장되는 것까지 확인한다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 256개 통과
  - 월간 그리드, 스케줄 보기, 날짜 상세 드래그의 개별 회귀 테스트 통과
- 사용자의 후속 업데이트 요청에 따라 기존 데이터를 유지하는 업데이트
  방식으로 다음 테스트 앱을 교체했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- 앱 자동 실행과 GUI 수동 테스트는 진행하지 않았다. App Store판
  `/Applications/Daily.app`은 변경하지 않았다. 이번 이슈 변경은 아직
  커밋하거나 원격 저장소에 푸시하지 않았다. #54·#56·#59 후속 변경까지 위
  macOS 및 iPhone 17 시뮬레이터 테스트 앱에 업데이트 설치했다.

### 2026-09-01 날짜 상세창 드래그·닫기 UX 후속 보정

- iOS 월간 날짜 상세창에서 일정을 잡아 상세창 바깥으로 이동하면 상세창을
  최소 높이까지 자동으로 접어 월간 날짜 셀을 더 넓게 사용할 수 있게 했다.
  최소 높이에 도달해도 상세창 자체가 닫히지는 않으므로 진행 중인 드래그와
  달력의 드롭 대상이 유지된다.
- macOS/iOS 공용 일정 드래그 피드백을 별도의 축약 카드가 아닌 사용자가 실제로
  잡은 일정 UI와 같은 크기·내용으로 변경했다. 드래그 중 원래 자리는 완전히
  투명하게 비우며, 드롭하지 않고 취소하면 원래 일정 UI가 즉시 복원된다.
- 상세창이 열린 동안 달력의 다른 날짜를 누르면 날짜 선택이나 일정 이동을
  실행하지 않고 상세창만 닫는다. 상세창 안쪽 조작은 그대로 유지하며 일정
  드래그 중에는 월간 달력의 드롭 대상이 입력을 받는다.
- 상세창 축소 도중 루트 포인터 취소 신호가 드래그를 조기에 종료하던 경로를
  제거했다. 실제 드래그 컴포넌트의 완료·취소 신호만 종료 상태를 결정한다.
- 설정의 `첫 화면` 4단 선택기에서 `빠른 보기`가 답답해 보이지 않도록 전체
  너비를 236px에서 248px로 소폭 넓혔다.
- 검증:
  - `git diff --check` 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 257개 통과
  - 상세창 바깥 탭 시 선택 날짜 유지, 원본 크기 피드백, 원본 숨김, 상세창
    최소화 후 월간 드롭, 취소 시 원위치 복귀를 회귀 테스트로 확인했다.
  - 빠른 보기 선택기의 248px 너비와 iOS 큰 글자 레이아웃을 확인했다.
- 사용자의 별도 업데이트 요청이 없으므로 앱 빌드·설치·실행과 GUI 수동 테스트는
  진행하지 않았다. 이번 후속 변경도 아직 커밋하거나 푸시하지 않았다.

### 2026-09-01 날짜 상세창 후속 수정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 최신 후속 수정본을 기존 데이터가 유지되는
  방식으로 다음 테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- macOS는 기존 샌드박스 컨테이너를 유지하고 Apple Development 서명을 검증한
  새 앱 번들만 교체했다.
- iOS Simulator의 `simctl install` 과정에서는 데이터 컨테이너 UUID가 새로
  할당됐지만, 기존 `daily.sqlite`, 환경설정 및 저장 상태 파일이 새 컨테이너로
  승계된 것을 확인했다. 앱을 제거하는 명령은 사용하지 않았다.
- 두 앱은 설치 전에 실행 중인 프로세스만 종료했으며 설치 후 다시 실행하거나
  GUI 수동 테스트를 진행하지 않았다. App Store판 `/Applications/Daily.app`은
  변경하지 않았고, 이번 변경도 아직 커밋하거나 푸시하지 않았다.

### 2026-09-01 일정 드래그 텍스트·재정렬 애니메이션 보정

- 월간 달력 일정의 드래그 미리보기에서 배경과 글자에 같은 분류 색을 사용해
  제목이 보이지 않던 문제를 수정했다. 별도 단색 미리보기를 없애고, 달력에
  표시되던 일정 바를 테마 표면 위에 그대로 들어 올리며 원래 자리는 완전히
  비운다.
- macOS/iOS 공용 일정 카드가 루트 오버레이로 이동할 때 원래 화면의 테마,
  기본 텍스트 스타일, 아이콘 테마 및 화면 배율을 함께 전달해 제목과 세부
  텍스트가 유지되도록 했다.
- 하루 일정 목록의 기존 위·아래 선형 드롭 표시를 실제 삽입 공간 애니메이션으로
  교체했다. 드래그 시작 시 카드 높이를 측정해 원본 자리를 접고, 포인터가 다른
  일정의 위·아래 절반을 통과하면 같은 높이의 자리표시자가 약 180ms 동안
  이동하면서 사이 일정들이 자연스럽게 비켜난다.
- 드롭하면 표시된 삽입 인덱스를 기존 수동 순서 저장 경로에 전달하고, 취소하면
  원래 카드가 제자리에서 다시 펼쳐진다. 날짜 간 이동과 iOS 상세창 자동 축소
  동작은 그대로 유지한다.
- 사용자가 제시한 iPhone 설정 화면은 4단 선택기가 제목 폭을 잠식해 `첫 화면`
  문구가 글자 단위로 줄바꿈되는 반응형 배치 문제로 분석했다. compact 폭에서는
  아이콘·제목/설명을 첫 줄, 3·4단 선택기를 다음 줄 전체 폭에 두는 개선 방향을
  설명했으며 이번 작업에서는 설정 UI를 변경하지 않았다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 258개 통과
  - 월간 드래그 제목/색상 대비, 목록 삽입 공간 이동, iOS 상세창 월간 드롭,
    취소 시 원위치 복귀 회귀 테스트 통과
  - `git diff --check` 통과
- 앱 빌드·설치·실행 및 GUI 수동 테스트는 진행하지 않았다. 이번 변경은 아직
  커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-01 iPhone 설정 선택기 반응형 배치

- 위 일정 드래그 항목에서 분석만 했던 설정 화면 반응형 개선을 사용자 승인 후
  적용했다. iOS compact 폭에서는 아이콘과 제목·설명을 먼저 충분한 폭으로
  표시하고, 3·4단 선택기 또는 제목과 한 줄에 함께 들어가지 않는 2단 선택기를
  다음 줄로 내려 제목이 한 글자씩 세로로 줄바꿈되지 않게 했다.
- 다음 줄로 내려간 선택기는 아이콘 뒤의 본문 시작점부터 카드 오른쪽 끝까지
  사용한다. iPhone 393px 기준 `첫 화면` 4단 선택기는 277px이며 제목과 설명
  아래에 배치된다. `월간 이동 방식`처럼 긴 2단 선택기도 공간이 부족하면 같은
  규칙을 사용한다.
- macOS 및 넓은 화면은 기존 한 줄 배치를 유지한다. macOS 900px 테스트에서
  `첫 화면` 선택기가 기존 248px 폭으로 제목 오른쪽에 남는 것을 확인했다.
- 테마, 주 시작 요일, 월간 이동 방식, 첫 화면, 주간·일간 표시 방식, 일정 제목
  정렬, 전체 UI 글자 크기, 잠금 방식, 일정 정렬 우선순위, 시간 표시 방식의
  캡슐 선택 행에 공통 반응형 규칙을 적용했다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub -r compact` 전체 259개 통과
  - iPhone 393px compact 배치, 큰 글자 130%, macOS 900px 한 줄 배치 회귀
    테스트 통과
- 사용자의 별도 설치 요청이 없어 앱 빌드·설치·실행과 GUI 수동 테스트는 하지
  않았다. 변경 사항은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-01 설정 반응형 수정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 설정 선택기 반응형 수정이 포함된 최신 코드를
  기존 데이터를 유지하는 방식으로 다음 테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- macOS는 기존 앱을 임시 백업 위치로 옮긴 뒤 새 Apple Development 서명 번들을
  설치·검증하고 백업 번들을 휴지통으로 이동했다. 앱 샌드박스의
  `daily.sqlite`와 환경설정 파일 SHA-256은 교체 전후 동일했다.
- iPhone 17 시뮬레이터는 앱을 삭제하지 않고 `simctl install`로 업데이트했다.
  데이터 컨테이너 UUID는 새로 할당됐지만 `daily.sqlite`와 환경설정 파일의
  SHA-256이 설치 전후 동일해 데이터가 그대로 승계된 것을 확인했다.
- 두 테스트 앱은 설치 전에 실행 중인 프로세스만 종료했으며 설치 후 자동으로
  실행하거나 GUI 수동 테스트를 진행하지 않았다. App Store판
  `/Applications/Daily.app`은 변경하지 않았고, 변경 사항은 아직 커밋하거나
  원격 저장소에 푸시하지 않았다.

### 2026-09-02 달력 전역 드래그 자리 비움·시간 이동 보정

- 하루 상세 목록에만 있던 드래그 원본 자리 접기와 삽입 공간 이동을 월간,
  주간, 일간 달력의 일정 드래그에도 공통 적용했다. 드래그 중 원본 일정은
  접히고, 포인터가 가리키는 삽입 위치에는 잡은 일정 높이만큼 공간이 열리며
  주변 일정이 약 180ms 동안 비켜난다.
- 월간 달력은 드래그 대상 날짜와 순서를 기준으로 일정 레인을 다시 투영하고,
  주간 목록은 각 일정의 위·아래 절반을 기준으로 삽입 위치를 계산한다. 반복
  일정은 occurrence 식별자를 포함한 키를 사용해 같은 일정의 여러 발생분이
  충돌하지 않게 했다.
- 드롭 수락 직후 원본이 잠깐 제자리로 돌아왔다가 저장 결과에 따라 다시
  이동하던 현상을 수정했다. 공용 pending-drop 레지스트리를 두고 일정 저장과
  순서 저장 Future가 실제로 끝날 때까지 드래그 원본을 숨긴 상태로 유지한다.
  취소된 드래그만 즉시 원위치로 복원한다.
- 주간·일간 스케줄 보기의 시간 일정은 드롭한 세로 위치를 15분 단위 시작
  시각으로 환산해 날짜뿐 아니라 시간까지 이동한다. 일정 길이는 유지하고,
  드래그 중 목표 시간 위치에 반투명 미리보기를 표시한다. 종일 일정은 기존
  날짜 이동 경로를 유지한다.
- 반복 일정 시간 이동은 `이번 일정`, `이 일정 이후`, `전체 반복 일정` 범위
  선택을 유지하면서 선택한 범위에 목표 시각을 적용한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 263개 통과
  - 월간 삽입 공간, 주간 삽입 공간, 스케줄 15분 단위 시간 이동, 저장 완료 전
    원본 숨김, 주간 가장자리 자동 이동 회귀 테스트를 포함한다.
- 사용자가 요청하지 않아 앱 빌드·설치·실행과 GUI 수동 테스트는 진행하지
  않았다. 이번 변경도 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 달력 드래그 보정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 달력 전역 자리 비움, 드롭 후 원위치 깜빡임
  방지, 주간·일간 스케줄 시간 이동이 포함된 최신 코드를 기존 데이터가
  유지되는 방식으로 다음 테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- `./tool/flutter.sh build macos --debug --no-pub` 및
  `./tool/flutter.sh build ios --simulator --debug --no-pub`가 통과했다.
- macOS는 실행 중인 테스트 앱만 종료한 뒤 기존 앱 번들을 휴지통에 백업하고
  Apple Development 서명된 새 번들로 교체했다. 번들 ID와 TeamIdentifier
  `A6Y73X2ZLS`를 확인했으며 App Store판 `/Applications/Daily.app`은 건드리지
  않았다.
- iPhone 17 시뮬레이터는 앱을 삭제하지 않고 `simctl install`로 업데이트했다.
  데이터 컨테이너 UUID는 변경됐지만 `daily.sqlite`와 환경설정 파일의 SHA-256이
  설치 전후 동일했다. macOS의 같은 파일들도 설치 전후 해시가 동일했다.
- 두 앱은 설치 후 자동 실행하지 않았고 GUI 수동 테스트도 진행하지 않았다.
  이번 변경은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 Apple 달력 드래그 입력·표시 후속 보정

- iOS/macOS 일정 드래그의 포인터 상호작용 상태와 저장 완료까지 유지되는 시각
  상태를 분리했다. 사용자가 손을 놓는 즉시 월간 달력의 드롭 대상 입력층을
  제거하므로 저장 중에도 날짜 선택 등 달력 입력이 막히지 않는다.
- 월간, 주간 목록, 하루 상세 목록, 주간·일간 스케줄은 드래그 중 목적지에
  색상·테두리·반투명 일정 미리보기를 표시하지 않고 삽입 공간만 비운다.
  드롭이 수락된 순간에는 저장 완료를 기다리지 않고 목표 위치의 실제 일정 UI를
  낙관적으로 표시하며, 실패하거나 취소되면 원래 위치로 복구한다.
- iOS 주간 목록은 날짜별 삽입 위치를 계산해 수동 순서를 저장하며, 실제 저장
  순서까지 회귀 테스트로 확인했다.
- macOS 우측 하루 보기에서 시작한 드래그는 월간 달력 영역에 들어가면 월간 일정
  막대 형태로 전환되고, 우측 사이드바로 돌아오면 원래 하루 보기 카드 형태로
  복원된다.
- 스케줄 시간 이동은 드롭한 15분 단위 목표 시각에 일정 블록을 즉시 표시한다.
  이전에 한 날짜 스케줄 드래그를 덮던 별도 월간 목적지 안내 UI는 렌더링하지
  않는다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub` 전체 265개 통과
  - iOS 하단 하루 보기에서 월간으로 드롭한 저장을 지연시킨 상태에서도 드롭
    입력층 제거, 바깥 탭으로 패널 닫기, 이후 날짜 선택이 정상임을 확인했다.
  - `git diff --check` 통과
- 사용자가 요청하지 않아 앱 빌드·설치·실행과 GUI 수동 테스트는 진행하지
  않았다. 이번 변경은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 Apple 달력 드래그 후속 보정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 월간 입력 먹통, iOS 주간 순서 변경, macOS
  우측 하루 보기 드래그 피드백, 드롭 후 깜빡임 및 목적지 힌트 제거 보정이
  포함된 최신 코드를 기존 데이터 유지 방식으로 다음 테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- `./tool/flutter.sh build macos --debug --no-pub` 및
  `./tool/flutter.sh build ios --simulator --debug --no-pub`가 통과했다.
- macOS 테스트 앱은 실행 중인 프로세스만 종료하고 Apple Development 서명된
  번들로 교체했다. 번들 ID와 TeamIdentifier `A6Y73X2ZLS`를 확인했으며
  App Store판 `/Applications/Daily.app`은 변경하지 않았다.
- iPhone 17 시뮬레이터는 앱 삭제 없이 `simctl install`로 업데이트했다. 양쪽
  테스트 앱 모두 `daily.sqlite`와 환경설정 파일의 SHA-256이 설치 전후 같아
  기존 데이터가 유지된 것을 확인했다.
- 설치 후 두 앱을 자동 실행하거나 GUI 수동 테스트하지 않았다. 변경 사항은 아직
  커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 Apple 목록·스케줄 드래그 및 하단 탐색 통합

- iOS/macOS 목록형 주간·일간 화면이 날짜별 수동 순서를 실제 렌더링에도
  적용하도록 통일했다. 완료된 일정도 직접 집어서 옮길 수 있고, 드래그 중에는
  원본 자리를 접고 목표 삽입 공간만 열어 주변 일정이 비켜난다.
- 일정 순서 저장처럼 공휴일 설정과 무관한 설정 변경은 일정 스트림을 다시
  만들지 않도록 provider 의존 범위를 공휴일 분류 필드로 한정했다. 드롭 직후
  목표 위치를 낙관적으로 유지하고 저장 완료까지 원본을 숨겨, 전체 목록이
  로딩 상태로 바뀌며 깜빡이던 경로를 제거했다.
- 스케줄형 주간·일간 일정 이동은 30분 단위로 맞춘다. 스케줄 안에서 시작한
  드래그는 목표 시각 힌트를 다시 표시하고 일정의 원래 시간 길이에 해당하는
  블록 크기를 유지한다. macOS 우측 하루 보기에서 시작한 스케줄 드래그는
  기존 시작 시각을 유지한 채 날짜만 바꾼다.
- macOS 우측 하루 보기 전체를 선택 날짜의 드롭 대상으로 만들었다. 일정이
  없는 빈 영역에도 놓을 수 있고, 주간·월간 목록의 일정 카드 위·아래 순서
  변경은 기존처럼 유지한다. macOS 스케줄형 일간 화면에도 선택 날짜의 우측
  하루 보기를 표시한다.
- macOS 우측 하루 보기에서 집은 일정의 실제 드래그 레터박스가 대상 화면에
  맞춰 월간 막대, 주간 카드, 일간 카드 또는 스케줄 블록 크기로 변한다. 포인터를
  레터박스 중앙에 고정해 크기 전환 때 마우스와 카드가 위아래로 어긋나지 않게
  했고, 스케줄 블록 높이는 일정 소요 시간으로 계산한다.
- iOS 하단 탐색은 `빠른 보기`, `주`, `월`, `일`, `Siri` 순서의 단일 5단
  슬라이드로 통합했다. 반투명 블러, 이동 렌즈와 눌림 반응을 사용하되 Apple의
  자산이나 고유 구현을 복제하지 않은 Daily 고유 구성이다.
- `LLM` 사용자 표기를 `Siri`로 바꾸는 범위는 **iOS와 macOS에만 해당한다**.
  Android와 Windows의 기존 하단 UI 및 `LLM` 표기는 변경하지 않는다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub --concurrency=1` 269개 통과
  - 통합 전 iOS 하단 UI 전용 테스트 1개는 새 5단 슬라이드 테스트로 대체되어
    기존 상태 그대로 skip 처리되어 있다.
  - `git diff --check` 통과
- 사용자가 요청하지 않아 앱 빌드·설치·실행과 GUI 수동 테스트는 진행하지
  않았다. 이번 변경도 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 Apple 목록·스케줄 보정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 최신 코드를 기존 데이터 유지 방식으로 다음
  테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- `./tool/flutter.sh build macos --debug --no-pub` 및
  `./tool/flutter.sh build ios --simulator --debug --no-pub`가 통과했다.
- macOS 테스트 앱은 실행 중인 프로세스를 종료한 뒤 Apple Development 서명된
  최신 번들로 교체했다. `codesign --verify --deep --strict`와 TeamIdentifier
  `A6Y73X2ZLS`를 확인했고, App Store판 `/Applications/Daily.app`은 변경하지
  않았다.
- iPhone 17 시뮬레이터는 앱을 삭제하지 않고 `simctl install`로 업데이트했다.
  데이터 컨테이너 UUID는 변경됐지만 양쪽 테스트 앱의 `daily.sqlite`와 설정
  plist SHA-256이 설치 전후 동일해 기존 데이터가 유지된 것을 확인했다.
- 설치 후 macOS와 iOS 테스트 앱을 자동 실행하거나 GUI 수동 테스트하지 않았다.
  변경 사항은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-02 Apple 드래그 피드백·사이드바 전환 후속 보정 및 업데이트

- iOS/macOS 스케줄형 주간·일간 드래그 피드백은 포인터가 레터박스 중앙을
  잡는 실제 표시 좌표를 기준으로 30분 단위 목표 시각을 계산한다. 일정 길이에
  따라 높이가 달라져도 포인터와 일정 블록의 상하 위치가 어긋나지 않는다.
- 일정 드래그 피드백을 대상 화면에 맞춰 공통 전환한다. 월간 달력에서는 실제
  월간 일정 막대 크기, macOS 우측 하루 보기에서는 사이드바 일정 카드 크기,
  스케줄에서는 일정 소요 시간에 해당하는 블록 크기를 사용한다. 월간과 우측
  사이드바 사이를 왕복할 때도 같은 드래그가 자연스럽게 원래 형태로 복원된다.
- 드롭 저장이 수락된 직후 기존 레터박스가 잠깐 작아졌다가 목적지 공간이 다시
  열리던 전환을 제거했다. 수락된 한 프레임은 최종 목록을 직접 배치하고 다음
  프레임부터 크기 애니메이터를 복원해, 목적지 공간과 일정이 한 번에 정착한다.
- macOS에서 우측 하루 보기가 필요한 주간·월간·스케줄 일간 화면끼리 이동할
  때는 사이드바를 동일한 위치에 고정한다. 사이드바가 있는 화면과 없는 화면
  사이에서만 너비와 투명도 전환 애니메이션을 적용한다.
- iOS 통합 하단 `빠른 보기 / 주 / 월 / 일 / Siri` 슬라이드는 캘린더 밖의 다른
  동작이 시작되면 전체 트랙이 다시 축소되고, 항목을 선택하면 원래 크기로
  확대되는 애니메이션을 사용한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub --concurrency=1` 270개 통과, 기존 의도된
    테스트 1개 건너뜀
  - `git diff --check` 통과
- 사용자의 업데이트 요청에 따라 기존 데이터를 유지하며 다음 테스트 앱을
  업데이트했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- macOS와 iOS 시뮬레이터 debug 빌드가 통과했다. macOS 설치본은 Apple
  Development 서명과 TeamIdentifier `A6Y73X2ZLS`를 검증했고 App Store판
  `/Applications/Daily.app`은 변경하지 않았다. iPhone 17 시뮬레이터는 앱을
  삭제하지 않고 업데이트 설치했으며, 양쪽 모두 설치 전후 `daily.sqlite`와
  설정 plist SHA-256이 동일했다.
- 설치 후 두 테스트 앱은 자동 실행하지 않았고 GUI 수동 테스트도 진행하지
  않았다. 변경 사항은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-03 Apple 일정 드래그 피드백 크기 전환 애니메이션

- macOS 주간·월간·스케줄 달력과 우측 하루 보기 사이를 일정 드래그로
  넘나들 때, 대상 화면에 맞춘 레터박스의 너비와 높이가 즉시 교체되지 않고
  170ms `easeOutCubic` 애니메이션으로 이어지도록 공용 드래그 피드백 전체를
  `AnimatedSize`로 감쌌다.
- 크기 전환은 피드백 중앙을 기준으로 진행되므로, 기존에 보정한 포인터와
  레터박스 중심 정렬을 유지한다. 월간 막대에서 사이드바 카드로 커지는 과정과
  사이드바 카드에서 월간 막대로 줄어드는 과정 모두 중간 크기를 거친다.
- 검증:
  - macOS 월간↔사이드바 피드백 전환 중간 크기 회귀 테스트 통과
  - 월간 그리드 및 스케줄 타임라인 테스트 35개 통과
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `git diff --check` 통과
- 사용자가 요청하지 않아 앱 빌드·설치·실행, GUI 수동 테스트, 커밋 및 푸시는
  진행하지 않았다.

### 2026-09-03 드래그 피드백 크기 전환 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 월간·주간·스케줄 달력과 macOS 우측 하루
  보기 사이의 드래그 레터박스 크기 전환 애니메이션이 포함된 최신 코드를 기존
  데이터 유지 방식으로 다음 테스트 앱에 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- `./tool/flutter.sh build macos --debug --no-pub` 및
  `./tool/flutter.sh build ios --simulator --debug --no-pub`가 통과했다.
- macOS 설치본은 `codesign --verify --deep --strict`와 Apple Development
  TeamIdentifier `A6Y73X2ZLS`를 확인했다. App Store판
  `/Applications/Daily.app`은 변경하지 않았다.
- iPhone 17 시뮬레이터는 기존 앱을 삭제하지 않고 `simctl install`로 업데이트
  했다. macOS와 iOS 모두 설치 전후 `daily.sqlite` 및 설정 plist SHA-256이
  동일해 기존 데이터가 유지됐다.
- 설치 후 두 테스트 앱은 자동 실행하지 않았고 GUI 수동 테스트도 진행하지
  않았다. 변경 사항은 아직 커밋하거나 원격 저장소에 푸시하지 않았다.

### 2026-09-03 Apple 드래그 피드백 축소 방향 애니메이션 재보정

- 첫 구현은 피드백 바깥 영역만 `AnimatedSize`로 보간하고 실제 레터박스는
  목표 크기로 즉시 교체했다. 이 때문에 확대 방향은 잘려 나오며 자연스럽게
  보였지만 축소 방향에서는 실제 일정 UI가 먼저 작아져 애니메이션이 없는 것처럼
  보이는 문제가 남아 있었다.
- 공용 피드백을 전용 상태형 크기 애니메이터로 교체했다. 드래그 시작 레터박스의
  실제 크기를 렌더 단계에서 기록하고, 월간·주간·일간·스케줄·사이드바 목표
  크기로 이동할 때 현재 애니메이션 위치부터 새 너비와 높이까지 실제 레터박스
  자체를 170ms `easeOutCubic`으로 보간한다. 빠르게 영역을 왕복해도 현재
  중간 크기에서 다음 전환이 이어진다.
- 회귀 테스트는 바깥 피드백 영역뿐 아니라 실제 사이드바·월간·스케줄
  레터박스가 확대와 축소 중간 크기를 거치는지 직접 검사한다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - `./tool/flutter.sh test --no-pub --concurrency=1` 270개 통과, 기존 의도된
    테스트 1개 건너뜀
  - `git diff --check` 통과
- 사용자가 요청하지 않아 이 재보정본은 아직 앱에 빌드·설치하거나 실행하지
  않았다. 커밋 및 푸시도 진행하지 않았다.

### 2026-09-03 양방향 드래그 피드백 재보정 테스트 앱 업데이트

- 사용자의 업데이트 요청에 따라 실제 레터박스 자체의 확대·축소 크기를
  양방향으로 보간하는 재보정본을 기존 데이터 유지 방식으로 설치했다.
  - macOS: `/Users/kimhwi/Applications/Daily Test.app`,
    `com.littlebit0.daily.test`, `3.3.1 (3.3.1)`
  - iPhone 17 시뮬레이터: `BF524643-403E-4212-ACB7-621E11279532`,
    `com.littlebit0.daily`, 표시 이름 `Daily Test`, `3.3.1 (3.3.1)`
- `./tool/flutter.sh build macos --debug --no-pub` 및
  `./tool/flutter.sh build ios --simulator --debug --no-pub`가 통과했다.
- macOS 설치본은 `codesign --verify --deep --strict`를 통과했으며 App Store판
  `/Applications/Daily.app`은 변경하지 않았다. iPhone 17 시뮬레이터는 기존
  앱을 삭제하지 않고 `simctl install`로 업데이트했다.
- macOS와 iOS 모두 설치 전후 `daily.sqlite` 및 설정 plist SHA-256이 동일해
  기존 데이터가 유지됐다. 설치 후 앱을 자동 실행하거나 GUI 수동 테스트하지
  않았으며 커밋 및 푸시도 진행하지 않았다.

### 2026-09-03 우측 사이드바 드래그 피드백 밝은 텍스트 섬광 제거

- 월간 일정을 macOS 우측 하루 보기 사이드바로 드래그할 때, 피드백
  높이가 아직 월간 막대 크기인 첫 프레임부터 사이드바용 제목과 밝은
  시간 텍스트, 10px 패딩을 모두 그리던 것이 순간 섬광의 원인이었다.
- 확장 초반에는 분류 색의 단일 제목만 안정적으로 보이고, 높이가 확보되면
  세로 강조선과 시간 텍스트가 점진적으로 나타나도록 렌더링을 분리했다.
  배경은 월간 막대 색에서 사이드바 카드 색으로 보간하고, `Material`의
  `surfaceTintColor`는 투명으로 고정했다.
- 검증:
  - 전환 첫 프레임에 제목만 있고 시간은 없으며, 확장 완료 후 시간이
    나타나는 macOS 회귀 테스트 통과
  - `test/widget_test.dart` 68개 통과, 기존 의도된 테스트 1개 건너뜀
  - `test/features/events/event_details_panel_test.dart` 10개 통과
  - `./tool/flutter.sh analyze --no-pub` 및 `git diff --check` 통과
- 사용자가 요청하지 않아 앱 빌드·설치·실행, GUI 수동 테스트, 커밋 및
  푸시는 진행하지 않았다.

### 2026-09-05 Android 이슈 #61 및 #36 수정과 태블릿 설치

- 이슈 #61의 Android Google 로그인 실패 원인을 실제 배포 APK와 OAuth
  등록 인증서의 SHA-1 불일치로 확인했다. Google Cloud 프로젝트에 GitHub
  배포 APK와 이 Mac의 디버그 키용 Android OAuth 클라이언트를 각각 추가했고,
  릴리스 워크플로가 공개 APK 서명 지문을 검증하도록 보강했다.
- 이슈 #36에 따라 Android 화면을 compact(<600), medium(600~839),
  expanded(>=840)로 구분했다. 태블릿에서는 여백·최대 너비·빠른 보기 열 수·
  일정 편집 창 크기가 반응형으로 바뀌며, expanded 화면은 360px 하루 보기
  사이드바를 사용한다. Android manifest의 large/xlarge 차단을 제거하고
  리사이즈 가능한 액티비티로 설정했다.
- 검증:
  - `./tool/flutter.sh analyze --no-pub` 통과
  - 전체 `./tool/flutter.sh test --no-pub` 313개 통과, 기존 의도된 테스트
    1개 건너뜀
  - Android compact/medium/expanded, 월간 밀도, 편집 창, manifest 및 APK
    서명 회귀 테스트 통과
- `Daily_Pixel_Tablet_API_36` AVD(Pixel Tablet, Android 16/API 36,
  Google Play, arm64)를 생성·부팅하고
  `build/app/outputs/flutter-apk/app-debug.apk`를 설치했다. 설치 패키지는
  `com.littlebit0.dailycalendar`, 버전은 `3.3.1`/versionCode `331`이다.
  앱은 실행하지 않았으며 실제 Google 로그인과 태블릿 GUI 검증은 사용자가
  직접 진행한다.
- 월간 그리드가 실제 달력 pane 너비를 받도록 한 공용 Flutter 변경은
  iOS/macOS에도 영향을 줄 수 있으므로 다음 Apple 빌드에서 월간 밀도 회귀를
  확인해야 한다. 커밋과 푸시는 진행하지 않았다.

### 2026-09-06 Android Google Drive 권한 연결 실패 후속 수정

- 사용자 화면의 `Authorization failed: 16: [28433] Cannot find a matching
  credential`은 계정 인증 이후 Android AuthorizationClient에서 발생하는
  오류다. 기존 `authorizationHeadersForScopes`가 이 GoogleSignInException을
  처리하지 않아 온보딩에 SDK 예외 원문이 출력되고 연결이 중단됐다.
- Pixel 9에 설치된 APK의 SHA-1은
  `69:A6:8E:1C:3F:53:1D:43:2D:81:9B:3E:B2:67:78:06:3C:71:6B:18`로,
  전날 등록했다고 기록한 Mac 디버그 키와 일치한다. 이번에는 Google Cloud
  등록 상태를 다시 조회하거나 OAuth 클라이언트를 변경하지 않았다.
- Android에서 해당 오류가 발생할 때에만 기본 계정의 권한 승인 경로로
  복구한다. 복구 토큰의 userinfo `sub`가 로그인 계정 ID와 일치해야만
  Drive/Calendar API 헤더를 반환한다. 다른 계정, 잘못된 응답, 로그아웃
  도중의 결과는 차단한다. 계정 이메일과 토큰을 로그에 기록하지 않는다.
- 자동 동기화는 복구 중에도 로그인/권한 화면을 열지 않는다. 사용자가 직접
  로그인/연결을 요청한 경우에만 대화형 승인을 허용한다. 일반 취소나 다른
  인증 오류는 반복 재시도하지 않고 안내 문구로 반환한다.
- 공유 Flutter 인증 파일을 수정했지만 계정 복구 분기는 Android 전용이다.
  iOS/macOS 네이티브 파일과 Windows OAuth 경로는 수정하지 않았다.
- 검증: 인증 서비스 테스트 15개, 기존 동기화/캘린더 가져오기 테스트 35개,
  `./tool/flutter.sh analyze --no-pub` 통과. Google 실제 계정의 로그인 성공은
  아직 검증하지 않았으며 사용자의 에뮬레이터 확인이 필요하다.
- Android arm64 디버그 APK 빌드와 서명 검증 후 기존
  `Daily_Pixel_9_API_36`에 `adb install -r -t`로 업데이트 설치했다.
  `3.3.1`/`331`을 유지하며 설정/보안 저장소 3개 파일의 설치 전후 SHA-256이
  동일함을 확인했다. Daily 앱은 직접 실행하거나 로그인 조작하지 않았다.
  커밋과 푸시는 진행하지 않았다.

### 2026-09-06 iOS 변경 사항 Android 대조 적용

- 상세 대조표는 `docs/ANDROID_IOS_PARITY.md`에 기록했다. Android 휴대폰에
  통합 5항목 하단 바와 확대/축소·드래그 애니메이션, 제한 너비 날짜 헤더,
  빠른보기 2열, 설정 선택 컨트롤의 세로 배치 및 공백 단위 줄바꿈을 적용했다.
  기존 Android 태블릿 레이아웃과 사이드바는 유지한다.
- 드래그 이동/순서/완료색/낙관적 저장/30분 스케줄 이동은 이미 공통 구현이다.
  iOS 하루 상세 시트의 월간 드롭 및 빠른보기 테스트를 Android에도 확장했다.
- Android LLM 버튼이 Apple `daily/signal_voice` 채널을 호출하던 문제를
  기존 `ChatInputBar`로 연결했다. 확인 후 등록 및 실패 후 재입력 가능하다.
  Android만 Gemini 3.6 Flash를 사용한다. 2.0 Flash 종료는 Google 공식
  문서로 확인했으며 API 호출은 하지 않았다. Windows의 기존 모델/음성 연결
  경로는 이번 범위에서 변경하지 않았으므로 Windows 에이전트의 후속 점검 필요.
- Android 캘린더 위젯은 작은 높이에서 주간, 큰 높이에서 월간으로 전환하며
  연속 일정을 주별 긴 막대로 표시한다. 완료 제목 분류색 유지, 시스템 테마
  변경 갱신, 미처리 체크 요청이 오래된 스냅샷으로 덮이지 않도록 보강했다.
  오늘 위젯은 keyguard 범주를 선언했지만 실제 잠금화면 배치는 호스트 지원에
  달려 있다.
- `daily/android_alarms` 네이티브 연결 추가: AlarmManager 정확한 예약,
  권한 승인, 제목/메모 알람 화면, 소리/진동, 중지/10분 다시 알림,
  수정·삭제·재부팅 후 예약 관리. 반복 알람은 iOS와 같이 제외한다.
  Google Play 제출 전 FSI/정확한 알람/foreground mediaPlayback 정책 확인 필요.
- Apple Siri/계정/지도 기능은 Android에 노출하지 않는다. iOS/macOS 네이티브
  파일은 이번 작업에서 변경하지 않았다. 공유 Dart의 iOS/macOS 자동 테스트는
  통과했지만 Apple 앱 재빌드/설치는 하지 않았으므로 다음 Apple 업데이트 시
  설정 및 헤더 레이아웃 실사용 확인이 필요하다.
- 검증: Flutter 전체 테스트 334개 통과(기존 건너뜀 1개), Android 네이티브
  Robolectric 9개 통과, analyze 및 `git diff --check` 통과, arm64 debug APK
  빌드/서명 검증 통과.
- `Daily_Pixel_9_API_36`의 `com.littlebit0.dailycalendar`에 업데이트 설치 완료.
  버전 3.3.1 / 331 유지. 설치 전후 일정 DB와 설정/보안 저장소 3개 파일의
  SHA-256 동일. 앱 실행 및 수동 조작하지 않았다. 실제 Google 로그인,
  Gemini 요청, 알람 울림/잠금화면, 위젯 호스트 테마 전환은 사용자 검증 필요.
  커밋 및 푸시하지 않았다.

### 2026-09-06 Android/iOS 월간 하루 일정 팝업 드래그 크기 왕복

- 하루 일정 팝업 안의 포인터를 뒤쪽 월간 달력 영역으로 잘못 판정하여
  내부 순서 변경 중에도 일정이 축소되던 문제를 수정했다. 팝업의 실제
  표시 영역(상단 손잡이와 safe area 포함)을 먼저 판정하며, 내부에서는
  원래 일정 카드의 크기와 UI를 유지하고 달력 가장자리 이동도 중단한다.
- 팝업 밖 달력 영역으로 진입할 때만 월간 일정 크기로 축소한다. 기존
  팝업 최소화 동작은 유지하며, 최소화된 팝업으로 돌아와도 원래 카드
  크기로 복원된다. 원래 UI 복원 경로에도 170ms 크기 애니메이션을 적용해
  양방향 전환과 애니메이션 도중 방향 변경이 현재 크기에서 이어진다.
- 공유 Flutter만 수정했다. iOS/macOS/Android 네이티브 구현과 일정 저장,
  날짜 이동, 순서 저장 로직은 변경하지 않았다. macOS 사이드바의 기존
  월간/상세 형태 전환 및 흰 배경 방지 처리를 유지한다.
- iOS/Android 월간 팝업 테스트에서 내부 이동, 손잡이 영역, 팝업 밖 축소,
  재진입 복원, 반복 왕복, 제목 유지, 포인터 중심 정렬 및 날짜 저장을
  검증했다. 별도 피드백 테스트에 복원 도중 역방향 전환도 추가했다.
- 검증: 관련 테스트 130개 및 전체 Flutter 테스트 334개 통과
  (기존 건너뜀 1개), analyze 및 git diff --check 통과.
- APK/Apple 앱 재빌드·설치 및 수동 실행은 하지 않았다. 다음 업데이트
  설치 후 실제 기기에서 팝업 드래그 감각 확인이 필요하다. 커밋/푸시 없음.

### 2026-09-06 월간 팝업 드래그 왕복 수정본 업데이트 설치

- 후속 업데이트 요청으로 Android arm64 debug APK와 iOS Simulator debug
  앱을 순서대로 빌드한 다음 기존 앱 위에 업데이트 설치했다.
- Android: `Daily_Pixel_9_API_36` / `emulator-5554`,
  `com.littlebit0.dailycalendar`, 버전 3.3.1 / 코드 331 유지.
  `adb install -r -t` 성공, APK 서명 검증 통과. 일정 DB 및 shared_prefs
  8개 파일의 설치 전후 SHA-256이 모두 동일함을 확인했다.
- iOS: 기존 iPhone 17 `BF524643-403E-4212-ACB7-621E11279532`,
  `com.littlebit0.daily`, 표시 이름 Daily Test, 3.3.1 (3.3.1) 유지.
  codesign 검증 및 `simctl install` 성공. 설치본 kernel_blob.bin 해시가
  새 빌드와 일치하며, 데이터 컨테이너 UUID가 변경됐지만 일정 DB와
  설정 plist의 SHA-256은 설치 전후 동일하다.
- 앱 실행 및 수동 UI 조작은 하지 않았다. macOS 앱, App Store 설치본,
  iOS/macOS 플랫폼 소스는 변경하지 않았다. 커밋/푸시 없음.

### 2026-09-06 월간 팝업 드래그 중 달력 전체 노출

- 사용자가 승인한 후속 방식으로 기존 0.4 높이 최소화를 대체했다.
  하루 일정 팝업에서 월간 달력 쪽으로 드래그하면 팝업 본문만 180ms 동안
  접고 하단 손잡이와 safe area를 복귀 영역으로 남긴다. 월간 달력의 크기,
  날짜 좌표, 스크롤 위치는 그대로이며 가려졌던 아래 날짜로도 드롭한다.
- 팝업 및 내부 DraggableScrollableSheet를 제거하거나 다시 생성하지 않는다.
  본문 원래 크기를 유지한 채 표시 범위만 접으므로 목록 상태와 원래 높이를
  보존한다. 기존 일정 피드백의 양방향 크기 애니메이션은 유지한다.
- 복귀 영역에 들어오면 팝업 본문과 잡고 있는 일정 크기를 복원한다.
  드롭/취소 시에도 저장 완료 대기와 무관하게 팝업을 원래 높이로 복원한다.
  애니메이션 중에는 미리 기록한 복귀 영역/펼친 영역으로 포인터를 판정해
  달력 하단으로 이동하다가 팝업이 반복해서 열리는 현상을 방지한다.
- iOS/Android, 좌우/상하 월간 이동 4개 조합에 화면 안전 여백을 포함해
  아래 날짜 드롭, 날짜 좌표 유지, 복귀 후 순서 저장, 취소 후 재드래그,
  비동기 저장 중 팝업 복원을 자동 검증했다.
- 공유 Flutter 화면 및 테스트만 수정했다. 네이티브 플랫폼 코드, 저장/
  동기화 로직, macOS 우측 사이드바는 변경하지 않았다.
- 검증: 전체 Flutter 테스트 336개 통과(기존 건너뜀 1개), analyze 및
  git diff --check 통과. 앱 빌드/설치/수동 실행, 커밋/푸시는 하지 않았다.

### 2026-09-06 월간 전체 노출 수정본 업데이트 설치

- 후속 업데이트 요청으로 Android APK 및 iOS Simulator 앱을 차례로
  새로 빌드하고 기존 앱을 삭제하지 않은 상태에서 업데이트 설치했다.
- Android `Daily_Pixel_9_API_36` / `emulator-5554`:
  `com.littlebit0.dailycalendar`, 3.3.1 / 331 유지. APK 서명 및
  `adb install -r -t` 성공. 일정 DB와 설정 파일 8개, 총 9개 파일의
  SHA-256이 설치 전후 동일하며 설치 후 앱 프로세스는 실행되지 않았다.
- iPhone 17 `BF524643-403E-4212-ACB7-621E11279532`:
  `com.littlebit0.daily`, Daily Test, 3.3.1 (3.3.1) 유지.
  codesign 검증 및 `simctl install` 성공. 설치본 Flutter 코드 해시가
  새 빌드와 일치하고 일정 DB/설정 plist의 설치 전후 SHA-256도 동일하다.
- 자동 실행 및 수동 UI 테스트는 하지 않았다. macOS 앱과 App Store판,
  iOS/macOS 플랫폼 소스는 변경하지 않았다. 커밋/푸시 없음.

### 2026-09-06 Android 사용 중 자동 Google 로그인 요청 차단

- 사용자 요구: Google 로그인/연결을 직접 시도하지 않았으면 앱 사용 중
  로그인 창을 임의로 띄우지 않는다. 시작/복귀/설정 진입/자동 동기화의
  `attemptLightweightAuthentication`은 Android에서 One Tap/계정 선택 UI를
  허용하므로 자동 경로에서 제거하고 방어 가드도 추가했다.
- 앱 재시작 후 기존 Daily Google 연결 이메일을 확인 대상으로 사용한다.
  화면 없는 `authorizationForScopes` 토큰의 userinfo email_verified/email을
  검사하고 sub를 고정한 뒤에만 계정 복원 및 Drive/Calendar 요청을 허용한다.
  로컬 이메일 자체를 로그인 근거로 취급하지 않는다. 연결 정보가 없거나
  권한 만료/네트워크 실패/다른 계정이면 자동 로그인으로 전환하지 않는다.
- Android 백업/복원/클라우드 백업 삭제 버튼도 promptIfNecessary=false다.
  명시적 Google 로그인 및 해당 흐름의 Drive 권한 승인은 유지했다.
  사용자가 직접 Google Calendar 가져오기를 선택한 경우 추가 권한 승인은
  허용하되, 기존 세션이 없으면 암묵적 signIn을 하지 않는다.
- 로그인 취소/로그아웃 이후 자동 복원으로 다시 창을 열지 않으며,
  로그아웃 또는 연결 계정 변경 중 도착한 이전 복원 결과는 폐기한다.
- 공유 Flutter 인증 서비스/DI/설정 및 테스트/문서를 수정했다. iOS/macOS
  네이티브 코드는 변경하지 않았다. 기존 Apple/데스크톱 인증 정책은 유지했고
  iOS/macOS 설정 버튼 및 비Android 네이티브 복원 회귀 테스트를 통과했다.
- 검증: 인증 테스트 30개, 전체 Flutter 테스트 353개 통과(기존 건너뜀 1개),
  analyze 통과, Android arm64 debug APK 빌드 성공. 로그인 UI 실사용 검증은
  사용자 요청이 없어 실행하지 않았다. APK 설치/앱 실행/커밋/푸시 없음.
  버전 3.3.1 / Android versionCode 331 유지. 기존 설치 앱/데이터는 미변경.

### 2026-09-06 Android 자동 로그인 차단 수정본 업데이트

- 사용자가 설치까지 이어서 처리해야 한다고 지적하여 위 수정본을 기존
  Android 테스트 앱에 업데이트했다. 빌드만 완료한 상태와 설치 완료 상태를
  구분하며, 이번 사용 중 버그 수정 흐름에서는 테스트 앱 업데이트까지 처리한다.
- 대상: `Daily_Pixel_9_API_36`, `emulator-5554`,
  `com.littlebit0.dailycalendar`, 3.3.1 / versionCode 331.
  `adb install -r -t` 성공, lastUpdateTime 2026-09-06 07:07:46.
- APK 서명 검증 통과. 설치된 base.apk SHA-256과 새 빌드가 일치한다.
  일정 DB 및 설정 파일 8개(총 9개)의 SHA-256은 설치 전후 모두 동일하다.
- 기존 앱을 삭제하거나 데이터를 초기화하지 않았다. 설치 후 앱 프로세스는
  없으며 앱 실행/로그인/실사용 테스트는 사용자에게 남겼다.
  iOS/macOS 설치본 및 App Store 앱, 커밋/푸시는 변경하지 않았다.

### 2026-09-06 일간 날짜 헤더/공휴일 색상 및 macOS 휠 재발 수정

- macOS/iOS/Android 일간 스케줄의 두 번째 날짜 행을 제거하고 상단 기간
  버튼에 전체 날짜/요일을 표시한다. 한국어는 `yyyy년 MM월 dd일 EEEE`,
  다른 언어는 해당 로케일의 전체 날짜 형식을 사용한다. 모바일에서는
  오른쪽 도구 버튼 공간을 제외한 폭 안에 날짜가 들어가도록 제한한다.
- 일간 목록은 날짜 전체가 아닌 요일 문자열만 주말/공휴일 색상을 적용한다.
  macOS 우측 하루보기와 일반 상세 팝업의 날짜 헤더는 기존 중립색을 유지한다.
- 주간 목록/스케줄에서 공휴일 서비스와 표시 설정으로 날짜 색상을 판단하며,
  일정 검색/분류 필터 결과에 공휴일 일정이 없어도 날짜 색상을 유지한다.
  공휴일 사용자 지정색, 일요일 빨강, 토요일 파랑 순으로 판단하고,
  오늘/선택일 강조가 이 색상을 덮지 않도록 공통 색상 함수를 사용한다.
  주/일간에 붉은 배경을 다시 추가하지 않는다.
- macOS 한 틱 이동 코드는 남아 있었으나 PageView의 기본 픽셀 스크롤과
  바깥 Listener의 페이지 이동이 동일 입력을 중복 처리했다. 안쪽 휠 입력
  중재 영역이 Windows에만 적용되어 있었으며, 페이지 애니메이션 도중에는
  DrivenScrollActivity의 IgnorePointer가 후속 틱 수신도 막았다.
- macOS에도 PageView 안쪽에서 pointerSignalResolver로 입력을 선점한다.
  애니메이션 도중 수신을 유지하고 틱마다 목표 페이지를 누적하여 빠른
  연속 입력도 버리지 않는다. 트랙패드 좌우 제스처, 스케줄 세로 시간 이동,
  Windows의 기존 burst 처리 정책은 유지한다. 월간 상하 연속 스크롤은
  변경하지 않았다.
- 기존 테스트 일부가 onPointerSignal을 직접 호출해 Flutter hit-test와
  기본 스크롤 충돌을 건너뛰었다. 실제 sendEventToBinding 입력으로 교체 및
  보강했다. 수정 전 월간 가로 1틱 미이동, 1차 수정 후 연속 틱 누락을 각각
  재현했고 최종 수정에서 모두 통과했다. 과거 모든 재발을 롤백으로 단정하지
  않는다. 이번 재발의 확인된 원인은 입력 처리 충돌과 검증 경로 누락이다.
- 검증: macOS/iOS/Android 및 화이트/다크 날짜 색상 테스트, 월/주/일 목록과
  주/일 스케줄의 단일/연속/반대 방향 휠, 트랙패드, 세로 시간 스크롤 테스트
  통과. 전체 Flutter 테스트 359개 통과(기존 건너뜀 1개), analyze 및
  git diff --check 통과. 실제 마우스/터치패드 수동 조작은 하지 않았다.
- 공유 Flutter 코드와 테스트만 수정했다. Apple/Android 네이티브 구현,
  저장/동기화 스키마, 버전 번호는 이 작업에서 변경하지 않았다.

### 2026-09-06 날짜/휠 수정본 세 플랫폼 업데이트 설치

- macOS → iPhone 17 Simulator → Android 순서로 빌드 및 업데이트 설치했다.
  버전 3.3.1 유지, Android versionCode 331. 앱 자동 실행과 실사용 테스트,
  커밋/푸시 및 릴리스 작업은 하지 않았다.
- macOS `/Users/kimhwi/Applications/Daily Test.app`:
  `com.littlebit0.daily.test`, 기존과 같은 Apple Development/팀 서명 확인.
  codesign strict/deep 검증 및 설치본 Flutter 코드 해시 일치 확인.
  일정 DB/설정 plist 해시가 설치 전후 동일하다. App Store 설치본
  `/Applications/Daily.app`의 실행 파일과 CodeResources 해시도 미변경.
  빌드 출력본의 LaunchServices 등록은 해제하고 설치 위치만 재등록했다.
- iPhone 17 `BF524643-403E-4212-ACB7-621E11279532`:
  `com.littlebit0.daily`, Daily Test. codesign 검증 및 simctl install 성공.
  새 설치본 Flutter 코드 해시가 빌드와 일치한다. 데이터 컨테이너 UUID는
  변경됐지만 일정 DB와 설정 plist 해시는 설치 전후 동일하다.
- Android `Daily_Pixel_9_API_36` / `emulator-5554`:
  `com.littlebit0.dailycalendar`, arm64 debug APK 서명 검증 및
  adb install -r -t 성공, lastUpdateTime 2026-09-06 07:28:18.
  설치된 base.apk와 빌드 해시 일치. 일정 DB/설정 9개 파일 해시 모두
  설치 전후 동일하고 stopped=true, 앱 프로세스 없음 확인.
- 남은 확인은 사용자의 실제 기기/입력장치에서 날짜 표시, 오늘/공휴일 색상,
  한 틱 및 빠른 연속 좌우 이동을 사용하는 수동 검증이다.

### 2026-09-06 빠른 보기 좌우 고정 및 일정 더블클릭 완료 전환

- 사용자 최종 지시: 빠른 보기는 월간 이동 방식 설정과 관계없이 항상 좌우
  슬라이드로 이전/다음 달을 이동한다. 상하 설정에 맞춰 세로 페이지 이동을
  적용했던 중간 해석은 폐기했다. 터치 상하 동작은 목록 스크롤만 수행한다.
  데스크톱 마우스 좌우 한 틱마다 월 이동, 빠른 연속/반대 방향 입력을 유지한다.
  긴 목록에서 세로 휠은 목록을 우선 스크롤하고 경계에서는 좌우 월 이동한다.
- 빠른 보기의 날짜 헤더 및 이전/다음 버튼도 항상 월 단위다. 주/일 화면에서
  빠른 보기로 들어가도 주/일 단위 이동이 남지 않는다.
- 일간 스케줄 상단 전체 날짜는 연/월/일과 아이콘은 중립색, 요일 텍스트만
  토요일/일요일/공휴일 색상을 적용한다. 두 번째 날짜 행은 다시 추가하지 않는다.
- 모든 OS 공유 Flutter 일정 항목에 더블클릭/더블탭 완료/미완료 전환 추가:
  월간 일정 막대, 주간 목록, 일간 목록, 주/일 스케줄 시간/종일 일정,
  우측 하루보기와 모바일 하루 팝업, 빠른 보기, 인라인 검색/별도 검색 결과.
  단일 클릭의 기존 날짜 선택/상세보기 및 길게 누르기 드래그는 유지한다.
  단일 클릭은 표준 더블탭 판별 시간 후 처리하며 첫 클릭에 상세창을 열지 않는다.
- EventCompletionAction은 기존 EventCommandService.setCompleted 경로를
  재사용한다. 일정 ID로 최신 저장 상태를 읽고, 반복 발생 ID가 있으면 해당
  발생 한 건만 처리한다. 같은 제목의 다른 일정은 변경하지 않는다.
  공휴일/시스템/읽기 전용/삭제된 일정은 변경하지 않으며 실패 시 오류를
  표시하고 재시도할 수 있다. 별도 저장/백업/알림/위젯 구현을 복제하지 않는다.
- 검증: 전체 Flutter 테스트 368개 통과(기존 건너뜀 1개). macOS/Windows는
  마우스 double click, iOS/Android는 touch double tap으로 모든 진입 위치를
  검증했다. 기존 단일 클릭 테스트는 표준 더블탭 판별 시간을 기다리도록 수정.
  드래그/순서 변경, 월 이동, 긴 목록 스크롤, 읽기 전용, 저장 실패 재시도,
  반복 한 건 완료 및 같은 제목 분리 테스트가 포함된다.
- 이번 변경은 공유 Flutter 코드/테스트이며 네이티브 플랫폼 구현과 DB/동기화
  스키마, 버전 3.3.1은 변경하지 않았다. Windows 실제 OS 빌드/실사용 검증은
  이 macOS 환경에서 수행하지 않았다. 사용자 요청 없이 앱을 자동 실행하거나
  실사용 UI/로그인 테스트를 하지 않는다. 커밋/푸시 및 릴리스는 별도 요청 사항이다.

### 2026-09-06 빠른 보기/더블클릭 최종 수정본 업데이트 완료

- 위 최종 지시 반영 후 다시 macOS → iOS → Android 순서로 빌드/설치했다.
  이전 중간 빌드의 설치 완료를 최종 수정본 완료로 보고하지 않는다.
  전체 테스트 368개 통과(기존 건너뜀 1개), analyze 및 git diff --check 통과.
- macOS: `/Users/kimhwi/Applications/Daily Test.app`,
  `com.littlebit0.daily.test`, 3.3.1(3.3.1). Apple Development 팀 서명 및
  strict/deep 검증 통과. 설치본/빌드 kernel SHA-256 일치:
  `e5d045a9a3ee633d088505b0a57592d2fc0cbc2caa120778b3317445176c3a77`.
  일정 DB와 설정 plist 해시가 설치 전후 동일하다. `/Applications/Daily.app`
  App Store 설치본의 실행 파일/서명 리소스 해시도 미변경이다.
- iPhone 17 Simulator: `BF524643-403E-4212-ACB7-621E11279532`,
  `com.littlebit0.daily`, Daily Test 3.3.1(3.3.1). 서명 검증 및 설치 성공,
  설치본/빌드 kernel SHA-256 일치:
  `7a21e268294257dd4e1193583f5832335f7774bae8e08ca8d81bece009815ecb`.
  새 데이터 컨테이너에서도 일정 DB와 설정 plist 해시가 설치 전후 동일하다.
- Android: `Daily_Pixel_9_API_36`, `emulator-5554`,
  `com.littlebit0.dailycalendar`, 3.3.1 / versionCode 331.
  APK 서명 검증 및 adb install -r -t 성공, lastUpdateTime
  2026-09-06 09:49:18. 설치본/빌드 SHA-256 일치:
  `55c34428d47ea689848403c019ed0f411d7e3fdca18df34ae02291234b6ab898`.
  일정 DB/설정 9개 파일 해시가 설치 전후 모두 동일하고 stopped=true 확인.
- 설치 후 앱 자동 실행/실사용 테스트는 하지 않았다. Windows 공유 코드와
  마우스 입력 자동 테스트는 반영했으나 Windows 네이티브 설치는 하지 않았다.
  기존 Swift API deprecation 및 Android 플러그인 Kotlin 전환 경고는 남아
  있으나 세 플랫폼 빌드는 성공했다. 커밋/푸시/릴리스는 진행하지 않았다.

### 2026-09-07 3.4.0 버전 승격 (배포 준비 1단계)

- 사용자는 원탭/더블탭 동작을 현재 상태로 유지하고 우선 버전만 3.4.0으로
  승격하도록 요청했다. 입력 판별 시간이나 UI/기능은 추가로 변경하지 않았다.
- pubspec 앱 버전 3.4.0, iOS/macOS 앱·테스트 타깃·위젯 빌드 설정과 위젯
  구성 스크립트를 3.4.0으로 갱신했다. Apple 표시 버전/빌드는 3.4.0 (3.4.0).
  Flutter 생성 설정은 다음 빌드 때 pubspec에서 다시 생성되며 직접 수정하지 않았다.
- Android versionName은 Flutter 버전을 사용하고 versionCode는 331에서
  340으로 올렸다. Windows MSIX 버전은 3.4.0.0, 파일명은 daily-windows-3.4.0.
  Windows 실행 파일 버전은 기존 Flutter 생성 버전 연결을 그대로 유지한다.
- YAML/Apple 프로젝트 plist 구조를 읽어 버전 일치를 확인했고, Apple 위젯
  구성 스크립트 문법 검사, 플랫폼 테스트 12개, analyze, git diff --check 통과.
- 이 단계에서는 앱 빌드/설치/서명/Transporter 업로드/커밋/푸시/릴리스 발행을
  하지 않았다. 기존 설치 앱과 데이터는 변경하지 않았으며, 설치본은 3.3.1이다.
- README의 공개 다운로드 링크 및 기존 릴리스·제출 기록은 변경하지 않았다.
  실제 3.4.0 릴리스 발행 전에는 새 릴리스 노트/README/제출 문서를 작성하고
  release-apple.yml 및 release-installers.yml의 body_path가 아직
  RELEASE_NOTES_3.3.1.md를 가리키는 부분도 해당 릴리스 노트로 갱신해야 한다.
