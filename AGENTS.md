# Daily Agent Rules

These rules apply to every Codex or local agent working inside this Daily
repository. Treat them as persistent project instructions, not as conversational
memory.

## 1. Follow Workspace Rules

- Also follow the workspace-level `AGENTS.md` at
  `C:\Users\com\Documents\New project\AGENTS.md`.
- If rules conflict, obey system/developer instructions first, then the user's
  latest explicit instruction, then this file.
- Read relevant code, tests, and handoff notes before changing behavior.

## 2. Preserve Existing Product Behavior

- Daily is a real production app. Do not use temporary workarounds, fake data,
  placeholders, hard-coded behavior, or silent feature removals.
- Existing features must be preserved unless the user explicitly asks to remove
  or replace them.
- Bug fixes should address the actual cause and should not mask failures.

## 3. Platform Boundary

- The macOS/iOS editing restriction applies only to agents running in a Windows
  environment. Windows-hosted agents may implement Windows/Android changes but
  must hand off required macOS/iOS platform changes in `AGENT_MEMORY.md`.
- Agents running on macOS may edit macOS and iOS platform implementation files
  as needed for the user's approved task, including native dependencies and
  build integration. Do not ask for a separate platform exception on macOS.
- Keep work within the approved feature scope; unrelated changes still require
  the user's approval when requested.
- Shared Flutter code may affect all platforms; after changing shared code,
  record any Mac/iPhone verification or porting needs in `AGENT_MEMORY.md`.

## 4. Cross-Platform Parity

- Windows, Android, macOS, and iPhone/iOS must keep the same user-facing
  calendar, sync, notification, auth, and settings behavior.
- Windows/Android changes that should also exist on Mac/iPhone must be handed
  off clearly in `AGENT_MEMORY.md`.

## 5. Sync Rules

- The old whole-file v1 sync behavior is abandoned for normal production sync.
- Use the v2 Google Drive AppData model:
  - `daily-sync-v2-event-{eventId}.json` per event.
  - `daily-sync-v2-settings.json` for settings.
  - Date-only fields for all-day events.
  - Tombstones for deletes.
  - Event-only uploads for local event create/update/delete changes.
- Do not reintroduce idle short-interval full polling as the default sync
  strategy.
- Sync should happen on meaningful lifecycle and data-change events: first
  start/sign-in/resume, local create/update/delete, and best-effort before
  background or exit.

## 6. Release Rules

- Version labels must not use a `+` suffix in user-facing release names.
- When publishing sync-schema-changing releases, upload Windows and Android
  artifacts together with Mac/iPhone artifacts. Do not publish only one platform
  family for a shared sync release.
- Never commit OAuth secrets, signing credentials, keystore passwords, tokens,
  or private provisioning material.

## 7. Verification

- Run the narrowest meaningful tests after focused changes.
- For shared behavior or release work, run `.\tool\flutter.ps1 analyze --no-pub`
  and `.\tool\flutter.ps1 test --no-pub` on Windows when available.
- For Android/Windows changes, rebuild and smoke-run the relevant app when the
  environment supports it.
- Report exactly what passed and what could not be verified.
- Unless the user explicitly says to defer updates (for example, "업데이트 보류"),
  finish an approved implementation task by updating the verified test app on
  the affected platform(s). Do not wait for a separate update request. Preserve
  installed test-app data and the App Store app; do not update unrelated platforms.
- Keep one current test installation per affected platform/device. Update the
  existing app in place with the same bundle/package identity and installation
  path; do not create version-named copies or uninstall as a routine update.
  Preserve app data, accounts and secure storage. Keep required backups separate
  from launchable `.app` bundles so they do not appear as duplicate test apps.
- Updating is not permission to launch the app, run personal automations or
  perform interactive usage tests. Do those only when the user requests them.
  If build/install verification is blocked, report the blocker instead of
  installing an unverified or stale artifact.

## 8. Handoff

- Keep `AGENT_MEMORY.md` current for cross-agent work.
- Record changed behavior, platform-specific constraints, verification results,
  release status, and remaining Mac/iPhone work.
- Do not rely on chat memory for critical project state.
