---
name: daily-auth-regression
description: Diagnose and verify DailyCalendar Google/Apple login, account selection cancellation, secure session restore, logout, or LMS authentication expiry and renewal. Use for identity/session regressions; do not treat mocked checks as live browser or multi-device proof.
---

# Daily auth regression

## Identify the auth boundary

- Google: `lib/core/sync/google_drive_auth_service.dart`, `lib/core/auth/google_account.dart`, `daily_account.dart` in the same directory, `lib/core/settings/settings_repository.dart` and account/settings actions in `lib/features/settings/presentation/settings_page.dart`.
- Apple: `lib/core/auth/apple_sign_in_service.dart`, `lib/core/auth/apple_account.dart` and native capability configuration.
- School: `lib/core/lms/lms_controller.dart`, `lib/core/lms/lms_web_session.dart`, `lib/features/settings/presentation/lms_login_page.dart`. This implementation uses WebView sessions and secure local cookie snapshots; do not describe a proposed independent mobile-token architecture as implemented.
- Native bridges: `ios/Runner/AppDelegate.swift`, `macos/Runner/MainFlutterWindow.swift`, `android/app/src/main/`, `windows/runner/`. Trace the actual platform branch and MethodChannel used by the failing operation.

Distinguish linked account metadata, Google authentication, granted Drive/calendar scopes and school authentication. Stored account metadata alone is not an authorized Drive session. Calendar read-only scope is separate from normal Drive AppData authorization.

## Regression cases

Select cases based on the affected branch; use existing fake platform implementations before live accounts.

| Change | Observe |
| --- | --- |
| Android account chooser / recovery | Cancellation completes cleanly, missing-credential recovery stays bounded, late native results cannot revive a cancelled or signed-out session |
| Google authorization / restoration | Verified identity matches the selected/linked account; account mismatch, unverified identity, expired access token and failed refresh retain correct state |
| Logout / account switch | Generation invalidation happens before awaited work; no old-owner results leak into the new owner; local cleanup and remote cloud deletion remain distinct actions |
| LMS restore / renewal | Root identity/origin and principal checks, login-form detection, network vs auth failure, bounded recovery, and secure-store lifecycle stay intact |
| Apple auth | Test real native capability and cancellation on supported Apple hosts; Google mock tests do not cover Apple sign-in |

`LmsWebSession` serializes activation, scopes storage to owner/school, uses a Windows WebView environment and an Apple nonpersistent cookie store bridge. Preserve strict cookie validation, permitted origins, read-only request constraints and secret-free `LmsWebSessionException`/authentication diagnostics. Do not print raw platform errors, bodies, URLs with queries, principal IDs, headers or storage contents to diagnose expiry.

## Checks

```bash
bash tool/flutter.sh test --no-pub test/core/sync/google_drive_auth_service_test.dart test/core/sync/startup_sync_gate_test.dart
bash tool/flutter.sh test --no-pub test/core/lms/lms_web_session_test.dart test/core/lms/lms_controller_test.dart test/core/lms/lms_persistence_test.dart test/core/lms/owner_scoped_event_repository_test.dart
python3 -m unittest discover -s tool/tests -p 'test_lms_cookie_read_policy.py' -v
```

The Python cookie-policy check compiles extracted production Swift policies when `swiftc` is available; skipped compiler checks are not passes. `test/widget_test.dart` includes linked-Google validation, local reset and logout behavior; use targeted `--plain-name` filters appropriate to the task before the full suite. Platform overrides/fake channels test service logic, not actual native login.

For live acceptance, use only the account actions authorized in the current request. An approved build/update does not authorize login/account change or interactive app launch (see root `AGENTS.md`). For LMS independence, record real successful issuance or authenticated session acceptance, reciprocal browser coexistence during login/re-login/renewal, second-device coexistence, and observed expiry separately. Failed grants, a second HTTP client or cached events prove none of those. Do not invent retention durations or restart deleted experiments from old handoff notes. Keep an authentication-only request scoped to token/session behavior.
