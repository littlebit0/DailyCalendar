# Analytics And Bug Report Deployment

Daily ships a first-party, aggregate-only analytics receiver. It is optional;
without `DAILY_ANALYTICS_ENDPOINT`, the app sends no analytics network request.

## Ubuntu Receiver

The Ubuntu receiver uses only the Python standard library. Copy
`tool/analytics_receiver.py` to the host and run:

```bash
DAILY_ANALYTICS_BIND=127.0.0.1 \
DAILY_ANALYTICS_PORT=8787 \
DAILY_ANALYTICS_DATA_DIR=/var/lib/daily-analytics \
python3 tool/analytics_receiver.py
```

For a per-user systemd deployment, install `deploy/daily-analytics.service`
under `~/.config/systemd/user/`, enable it with `systemctl --user enable --now
daily-analytics`, and enable lingering for that service account so the receiver
starts after a reboot without an interactive login.

Run it under a dedicated unprivileged system user. Put an HTTPS reverse proxy
in front of `127.0.0.1:8787`, disable request-body and access logging for the
ingestion path, and expose only:

- `POST /v1/events`
- `POST /v1/bug-reports`
- `GET /health`

The receiver limits a request to 64 KiB and 25 events, applies an in-memory
per-address rate limit, revalidates the allowlist, and never logs request
bodies. Daily aggregates are stored in `analytics-YYYY-MM-DD.json`; delivery
dedupe hashes are stored separately. Aggregate files expire after 90 days and
dedupe files after seven days.

## Authenticated Bug Reports

The bug-report endpoint is separate from anonymous analytics. It runs only when
the user explicitly submits the in-app form and is available only while Daily
has an active Google session.

The app sends its Google bearer token to `/v1/bug-reports`. The receiver uses it
once with Google's OpenID Connect UserInfo endpoint, requires a verified email,
and never writes the bearer token to disk or logs. It then creates an issue in
`littlebit0/DailyCalendar` using a server-side GitHub credential owned by the
`littlebit0` account. The public issue contains the report and app environment,
but not the user's email address.

Create a fine-grained GitHub personal access token with access only to the
`littlebit0/DailyCalendar` repository and `Issues: Read and write`. Store it
outside the repository:

```bash
install -d -m 700 "$HOME/.config/daily"
read -rsp "GitHub token: " DAILY_GITHUB_TOKEN; echo
umask 077
printf 'DAILY_GITHUB_TOKEN=%s\n' "$DAILY_GITHUB_TOKEN" \
  > "$HOME/.config/daily/bug-report.env"
unset DAILY_GITHUB_TOKEN
systemctl --user restart daily-analytics.service
```

The service loads this file through `EnvironmentFile` and never places the
credential in source control. Verified contact mappings are stored under
`/mnt/storage/daily-analytics/bug-report-contacts` with directory mode `0700`
and file mode `0600`; they expire after 365 days. Each Google identity is limited
to five accepted reports per hour.

## App Build

Use the public HTTPS ingestion URL only in a release build:

```bash
./tool/flutter.sh build ipa --release \
  --dart-define=DAILY_ANALYTICS_ENDPOINT=https://analytics.example.com/v1/events \
  --dart-define=DAILY_BUG_REPORT_ENDPOINT=https://analytics.example.com/v1/bug-reports
```

Use the same `--dart-define` for the macOS build. A missing endpoint is a valid
privacy-safe configuration: consent can still be disabled or cleared, and no
network transmission occurs.

## Current Production Receiver

- Public endpoint: `https://littlebit.tail6514a4.ts.net/v1/events`
- Bug-report endpoint: `https://littlebit.tail6514a4.ts.net/v1/bug-reports`
- Health endpoint: `https://littlebit.tail6514a4.ts.net/health`
- Ubuntu service: `daily-analytics.service` (user systemd service)
- Receiver source: `~/.local/lib/daily-analytics/analytics_receiver.py`
- Aggregate storage: `/mnt/storage/daily-analytics` (HDD)
- Public HTTPS: Tailscale Funnel to `127.0.0.1:8787`

The `3.3.1` iOS and macOS App Store artifacts in
`dist/transporter-upload/3.3.1` include this endpoint. Collection remains off
until the user explicitly enables anonymous usage analytics in Daily.

## Verification

1. Leave `익명 사용성 분석 허용` off and verify that no ingestion request is
   received.
2. Turn it on and use calendar views, event editing, search, filters, and manual
   sync.
3. Verify the receiver aggregate contains only allowlisted enums and numeric
   measurements.
4. Confirm that no aggregate or dedupe file contains a session ID, event ID,
   account, calendar content, search text, token, or network address.
5. Disconnect the receiver, create events, and verify calendar and Drive sync
   still succeed while the bounded analytics queue waits independently.
6. Turn analytics off or use `분석 데이터 삭제` and verify the local queue is
   removed.
7. With a Google-signed-in test account, submit a bug report and verify that the
   GitHub issue contains the report but not the email address.
8. Confirm the matching private contact file is mode `0600`, contains the issue
   number and verified email, and never contains the bearer token.

Automated coverage for these boundaries is in:

- `test/core/analytics/privacy_analytics_service_test.dart`
- `test/core/analytics/analytics_receiver_test.dart`
- `test/core/support/bug_report_service_test.dart`
- `test/tool/analytics_receiver_test.py`

## Test app version separation

Packages ending in `.test` retain their actual installed version and report
`appVersion` as `<version>-test` (for example, `4.0.0-test`). Production packages
continue reporting the numeric version. Both Python and Dart receivers accept
only this optional suffix and aggregate the two versions separately. The app's
settings label identifies a test version without changing its bundle identity,
version number, analytics consent, or user data.

Update the deployed Python receiver before installing an app that sends the test
suffix. Existing records without the suffix cannot be retroactively classified
as production or test.

## Reading durations (#151)

Durations are capped at 120000 ms. Apps that send `durationTruncated: true` ran
longer than the cap; a record with `durationMs` 120000 and no flag is exactly
120 s **only if it came from an app that already sends the flag**. Records from
older apps (and everything collected before this change) cannot tell exact 120 s
from longer, so treat their 120000 values as "at least 120 s" and do not average
them as true durations. `durationTruncated` is optional and only ever `true`; the
receiver must be deployed before the app that sends it, or the batch is rejected.

## Frame health (#150)

`frame_summary` replaces per-batch `slow_interaction_detected`/`frame_batch` records
for new apps (old records stay valid). Each event covers one window of foreground
frames (up to 3600 frames or 10 minutes, or earlier at `flush`/refresh-rate change):
`frameCount`, `slowFrameCount`, the longest frame `durationMs`, `refreshRateHz` and
`buildMode`. A frame is slow when its total span exceeds **two display periods at the
actual refresh rate**, so `slowFrameCount / frameCount` is comparable across 60, 120
and 144 Hz screens. Frames while the app is not resumed are not counted. `debug` and
`profile` windows should be excluded from release-quality statistics. Synthetic
`FrameTiming` tests verify the rule; real jank on devices needs a profile/release
measurement. Deploy the receiver before the app, as for every new event name.

## Startup (#149)

`app_load_completed` is unchanged: it ends when the data migration finishes (measured
from the bootstrap widget) and says nothing about the calendar being visible. Two new
`startup_milestone` events, each sent once per process, measure from the start of the
Dart `main` (OS process launch and native splash time are not included):
`firstCalendarFrame` (first frame after the calendar screen mounts) and
`localCalendarReady` (the month, week and day providers have loaded the local
events; external sync, LMS and Drive do not delay it). A failed local load sends no
`localCalendarReady`. Earlier `app_load_completed` records keep their meaning.
Deploy the receiver before the app.

## Sync attempts (#152)

Every `sync_started` now ends in exactly one terminal event while the app keeps
running: `sync_succeeded`, `sync_failed` (failed or canceled), or the new
`sync_abandoned` (`reason: sessionChanged`, the account or session changed under the
sync). `sync_abandoned` is not a failure of the sync and must not be counted in a
failure rate. Automatic retries carry an optional `attempt` (2-6); the first attempt
has none, so `sync_started` without `attempt` counts logical syncs and the rest are
retries of them. No attempt identifier or other linking value is sent.

A started sync with no terminal event in the same period is **unknown**, not failed:
it may be still running, cut off by the app being closed, or lost with the pending
queue (200 events / 7 days) or an unreachable receiver. Compute
`unknown = started - (succeeded + failed + abandoned)` over a window that excludes
the most recent minutes, and never treat it as a failure. Deploy the receiver first.

## Feature usage (#153)

`feature_used` records only the features below, so **a missing record is never
evidence of zero use**. The event's `outcome` means:

| feature | measured | `succeeded` | `canceled` | `failed` |
|---|---|---|---|---|
| `search` | search panel opened | panel opened (not a search result) | - | - |
| `filter` | filter sheet closed | at least one filter changed (query, hidden categories, holidays, D-day only) | closed with no net change | - |
| `widget` | widget Todo actions processed in the app | actions applied | - | - |
| `calendarImport` | an import run from the import page | the run finished without error | - | the run threw |
| `map` | **not measured**: the native chooser reports "handled" for both opening a map and dismissing the dialog | - | - | - |
| `siri` | **not measured**: Siri intents run in the OS/extension without the Dart app | - | - | - |

Search text, imported event content, locations and Siri phrases are never recorded.
Records written before this change used `succeeded` for every filter-sheet close;
that older meaning is not reinterpreted. Receivers need no change (existing enums).
