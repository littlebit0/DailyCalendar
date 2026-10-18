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

- Complete the entire requested implementation scope before combined verification
  and review. Do not repeat full checks, builds or installs for each small change
  or source packet. After correcting failures, rerun the narrowest meaningful
  checks for changed and directly affected behavior; broaden only for concrete
  global impact or mandatory requirements. Keep necessary pre-action security,
  data-loss checks and execution error handling.
- Distinguish implementation completion from verification and device acceptance.
  Usage forecasts do not authorize omitted work or unlimited spending.
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

- Keep `AGENT_MEMORY.md` as the concise current handoff/index for cross-agent work.
  Consolidate same-purpose handoffs; preserve superseded evidence in `docs/archive/`
  and link it rather than accumulating contradictory live instructions.
- Record changed behavior, platform-specific constraints, verification results,
  release status, and remaining Mac/iPhone work.
- Do not rely on chat memory for critical project state.

## 9a. Roles: Claude implements, Codex reviews, the user merges

- Claude does the main work: analysis, implementation, tests, build/run/install,
  commits, pushes and opening pull requests. One issue per branch and per PR,
  `Closes #N` in the PR body, Korean commit messages and PR text, no Claude
  attribution lines. Verify once right before committing; rerun only the part
  that failed.
- Codex is the reviewer. It does not commit, push, edit the PR branch, or merge.
  It reviews every pull request automatically when the PR is opened and again
  when new commits are pushed, and reports only through PR review comments.
- The only channel between the two is GitHub: Claude reads Codex's review
  comments with `gh`, answers them in the PR, and pushes fixes to the same
  branch. Neither agent merges; the user decides and merges.
- If automatic review does not start, the user (or Claude, as a PR comment) asks
  with `@codex review`.

## Code Review Rules

Codex: review pull requests against these rules. Report only findings you can
tie to a specific file and line, and say what you did not verify.

- Data loss and consistency: anything that can drop, overwrite or duplicate user
  events, completion state, memos, exclusions, tombstones or credentials. Check
  concurrent writes, partial failure and retry behaviour.
- Sync (section 5): v2 per-event files, date-only all-day fields, tombstones,
  event-only uploads. Flag whole-file sync, idle polling, or schema changes made
  without the user's approval.
- Cross-platform parity (section 4): the same behaviour on Windows, Android,
  macOS and iOS. A Dart change that has Swift/Kotlin/C++ counterparts (Siri,
  widgets, wallpaper, notifications) must update them or say why not.
- Dates and recurrence: daylight-saving days, month ends, leap days, time zones,
  all-day versus timed events.
- Security and privacy: secrets, tokens, logging of personal data, credential
  storage that deletes originals on failure.
- Honest reporting: a PR must not claim more than it verified. Flag claims of
  passing CI that rest on a partial run, skipped tests, or a different commit,
  and flag missing tests for new non-trivial logic.
- Out of scope for blocking: style-only comments, unrelated refactors, and
  product behaviour that the linked issue did not ask to change.

## 9. Repository Codex Skills

Project-scoped skills live in `.agents/skills/`. Select the relevant entrypoint
instead of loading every skill for each task:

- `dailycalendar-project`: Flutter architecture, repository orientation and tooling.
- `daily-lms-sync`: Coursemos parsing, import completeness and cache visibility.
- `daily-auth-regression`: Google/Apple/LMS identity, cancellation and session checks.
- `daily-calendar-integrity`: dates, recurrence, migrations and Drive merge/deletion rules.
- `daily-cross-platform-check`: affected-platform builds and verification evidence.

These skills supplement the rules above and do not grant additional permissions.
Skill/configuration-only edits do not require updating or launching installed apps.
See `docs/CODEX_SETUP.md` for discovery and external plugin connection boundaries.

# 명시한 요구와 판단 위임의 경계 — 항상 적용

- 사용자가 대상·형태·기준을 지정한 경우, 다른 대상이나 형태로 임의 대체하지 않는다. 확인하지 않은 내용을 추측해 적용하지 않는다.
- 요구를 충족할 자료를 확인하지 못했거나, 서로 다른 해석이 결과에 실질적인 차이를 만들면 구체적인 선택지와 불확실한 점을 설명하고 사용자에게 먼저 묻는다. 질문에 대한 답이 오기 전에는 그 답에 의존하는 변경을 진행하지 않는다.
- 사용자가 해당 질문에 대해 명시적으로 “알아서 하라” 등 판단을 위임한 범위는 스스로 판단해 진행한다. 다른 범위에까지 위임을 확대하지 않는다.
- 자료 수집·현재 코드 확인 등 답에 의존하지 않는 작업은 계속한다. 합의된 범위 내의 통상적인 구현 선택마다 불필요하게 반복 확인하지 않는다.

## Confirmed feedback and recurrence prevention

- Treat user corrections supported by records as actionable feedback. Record the specific mistake and a concrete prevention rule; do not replace correction with appeasement or unsupported admissions.
- Do not say work will continue after ending a turn unless an actual continuation mechanism is running and verified. A final response alone does not keep this agent working.
- Give time estimates only with an explained basis and uncertainty. Distinguish active work, remote queue/runtime, and paused work; never present an unmeasured estimate as established.
- For CI portability, inspect test inputs, generated output locations, absolute paths and host-specific assumptions before claiming clean-checkout reproducibility. After a combined run, rerun only failed/changed checks and directly affected scope unless broader checks are required.

- Confirmed CI reporting failure (2026-10-13): the agent added [skip ci], ran only 45 selected tests, then reported all CI failures resolved. Never substitute a selected green run for full CI acceptance. Before claiming completion, compare the requested scope, actual run commit/event/jobs/test scope, and final conclusions. Do not introduce CI-skipping or scope-reduction mechanisms to meet an all-CI request.
