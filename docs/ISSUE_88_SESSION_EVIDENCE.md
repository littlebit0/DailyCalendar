# Issue 88: browser login and Daily session loss

2026-09-29. Public-source audit, local implementation review and separately
authorized app diagnostics/UI reproduction. Public research did not use the
user's school session. Credentials, cookies and browser storage were not
exported or included in the evidence reports.

## Observed boundary

### Confirmed Chrome reproduction on 2026-09-29

The user confirmed the sequence: a fresh Daily login at08:44:45 KST, followed
by a new login in Chrome. PID36937's actual last successful source sync was
08:45:02.979 KST. Controller ready acknowledgments continued to08:45:18.128,
then the following sequence occurred at08:45:19:

1. `readRedirect` at19.005, followed by `recoveryStarted`.
2. Current private store: `rootLoginForm` at19.328.
3. `snapshotRestoreStarted`, then another `rootLoginForm` at19.650.
4. `credentialsDiscarded` only after those two root rejection results.

This is not the residual endpoint401 disposal path fixed in the final build.
It demonstrates that Daily classified both current and restored root documents
as unauthenticated immediately after the user-confirmed Chrome login. A
normal UI inspection subsequently showed the actual school login form, with
visible username/password fields and the school's own session-ended message.
Root entered/submitted no credentials and cancelled the view afterward. This
excludes a merely hidden-password-input false positive for this reproduction.
The specific school concurrent-login configuration has not been inspected.

The scoped cached database still contains28 events with no duplicate IDs:
17 known complete,8 known incomplete,3 unknown. All25 known completion values
match Daily. No event was deleted by this authentication failure.
Evidence: `work/issues-87-88/mac-session-after-chrome-36937.json` and
`work/issues-87-88/mac-completion-after-chrome-36937.json`.
The exact source-success timestamp is in
`work/issues-87-88/mac-session-after-chrome-timing-36937.json`.
`refreshConfirmed` can also acknowledge the service's recent-result throttle;
it is not independently proof of a new school request at every such timestamp.

The attempted read-only VM DOM classifier was unavailable because expression
compilation failed. A standard Flutter debugger attachment (without reload)
provided the initially missing compilation service, but the expression still
failed. No DOM classifier result exists. The normal app UI, not VM evaluation,
provided the actual-login-form observation above.

### Earlier observation

The user reports that logging into LMS in Chrome disconnects Daily. Root's
separate authorized diagnostic of Mac PID 24852 found a bound private store,
no authenticated principal, a retained expected principal, and one consumed
recovery attempt. The prior diagnostic did not retain the rejection branch;
its generation value alone cannot identify the cause. Cached events remained.
Evidence files: `work/issues-87-88/mac-session-flags-expired-24852.json` and
`work/issues-87-88/mac-completion-cached-24852.json`. The browser-login causal
relationship was not established at that earlier checkpoint; the confirmed
reproduction above supersedes that limitation. The precise school policy still
requires separate evidence.

## Official source findings

### Research follow-up: viable directions, not implementation approval

The observed limitation is restoration of an already rejected web session,
not proof that Daily integration is impossible. Public configuration probes
returning 404 or an unexpected envelope do not prove mobile services disabled.
Standard Moodle behavior is reference evidence, not SMU version/configuration.

- Preferred standalone product direction: school-supported external-client
  authentication and read APIs. Moodle mobile tokens have `sid = null` and a
  server-set expiry, while the web concurrency helper excludes web services.
  Existing services may suffice; a new school-built API is not necessarily
  required. Verify Daily callback/service eligibility AND calendar, assignment,
  quiz submission and Coursemos learning-report coverage before committing to
  this direction. A token alone does not authorize the current HTML reports.
  [Token implementation](https://github.com/moodle/moodle/blob/MOODLE_405_STABLE/lib/external/classes/util.php#L339-L395),
  [mobile authentication configuration](https://docs.moodle.org/311/en/Moodle_app_guide_for_admins#Mobile_authentication).
- Desktop fallback candidate: a Chrome companion reads permitted report DOM
  using the user's existing browser login and transfers normalized own-account
  data via Native Messaging. Do not export cookies/passwords or create a second
  LMS login. Chrome documents both capabilities, but school compatibility is
  untested. Browser availability, session expiry, extension installation and
  site changes remain constraints. Mobile can receive imported event changes
  through the existing Drive model; this is not standalone mobile LMS fetching
  or guaranteed instantaneous delivery. No player/quiz attempts are opened to
  obtain status. [Content scripts](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts),
  [Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).
- Complementary calendar feed: standard Moodle exports use a separate token
  and `NO_MOODLE_COOKIES`. An enabled school feed could provide deadline events
  independently of browser login. School availability and exported coverage are
  unverified; it does not establish attendance/progress/submission semantics.
  [Calendar export](https://docs.moodle.org/en/Using_Calendar#Calendar_export),
  [export authentication](https://github.com/moodle/moodle/blob/MOODLE_405_STABLE/calendar/export_execute.php#L23-L54).
- Existing WebView plus reauthentication preserves current functionality but
  is not a Chrome-coexistence solution. Repeated automatic fresh login may
  invalidate the other session if the server enforces that policy; this is a
  risk to test, not an observed reverse-direction result.

Recommended evidence gates before product changes: compare two ordinary browser
sessions to separate a general web-session restriction from a Daily-specific
failure; compare official Coursemos app with Chrome; then validate externally
permitted app authentication and required data coverage. These comparisons were
not performed in this research turn. No new credentials, grants or authenticated
school requests were used. Product code and installed apps remain unchanged.

- Moodle 3.11 supports a configurable concurrent-login limit. The default is
  unlimited; enabled limits terminate the oldest sessions. The documentation
  explicitly excludes SSO plugins. The standard login handler calls the limit
  helper, but this does not establish SMU's custom SSO behavior.
  [Moodle 3.11 authentication settings](https://docs.moodle.org/311/en/Managing_authentication#Limit_concurrent_logins),
  [standard login call](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/login/index.php#L210-L213),
  [helper and SSO caveat](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/classes/session/manager.php#L859-L913).
- With `tracksessionip` enabled, Moodle terminates a session whose current
  address differs from its recorded address. This concerns one session changing
  networks; it does not by itself forbid concurrent sessions. The inspected
  core security check does not compare User-Agent. School authentication plugins
  may impose separate rules, which have not been verified.
  [security check](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/classes/session/manager.php#L579-L596),
  [IP-setting explanation](https://docs.moodle.org/311/en/tracksessionip).
- A normal Moodle login regenerates that login's session identifier. This is
  not evidence that it replaces a different browser's isolated session.
  [login implementation](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/classes/session/manager.php#L598-L619).

## Daily isolation and remaining candidates

Daily's Apple settings use `incognito: true` and `sharedCookiesEnabled: false`.
The installed flutter_inappwebview Apple implementations select a nonpersistent
`WKWebsiteDataStore`; copying `HTTPCookieStorage.shared` cookies is conditional on
the disabled shared-cookie setting. Native binding requires the exact private
WebView's random marker and school host, and rejects persistent stores.
No inspected path reads Safari/Chrome storage. Native `clear` affects only that
bound private store. This local isolation does not prevent server-side revocation.
[Apple nonpersistent data store](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/nonpersistent()).

Local source: `lib/core/lms/lms_web_session.dart`,
`macos/Runner/MainFlutterWindow.swift`, and `ios/Runner/AppDelegate.swift`.
Plugin source: `flutter_inappwebview_macos-1.1.2/macos/Classes/InAppWebView/InAppWebView.swift`
and `flutter_inappwebview_ios-1.1.2/ios/Classes/InAppWebView/InAppWebView.swift`
under the package-config-resolved Pub cache. The login and headless views use
the same Daily WebView settings, with no custom User-Agent override.

The saved public school-login markup contains no verified concurrent-login/IP
policy. The existing feasibility note proves that a custom SSO form exists,
not how its server invalidates sessions. Neither a general Moodle feature nor
a browser-login timing report is sufficient to assert that policy is enabled.

## Diagnosing and preventing premature local disposal

Previously, the single `authentication_required` result merged an opaque
redirect, HTTP 401, current-document origin change, a password field, and a
different principal. A successful root restoration also consumed the recovery
budget for the rest of that session. The recovery started by writing the saved
snapshot, potentially overwriting a cookie updated by the preceding response.

The revised implementation records at most 24 in-memory diagnostics containing
only an enum reason, UTC timestamp, and lifecycle generation. It records no
URLs, identifiers, response text, passwords, cookies, or tokens. The existing
password-field predicate remains unchanged pending actual response evidence.

Recovery now validates the live private store's root first. A matching principal
preserves the current store; only an explicit login-form response permits one
saved-snapshot attempt. A different principal forbids restoration. Unknown or
failed root checks preserve material and report fallback, including subsequent
lifecycle retries. Repeated redirects/origin changes alone do not clear cookies.
The owning controller renews the retry budget only after a complete successful
sync, retaining one retry per failing refresh.

A further review found that a second HTTP 401 or password-form response from an
individual endpoint still discarded authentication despite a successful root
check. That path now performs one final current-root validation and never
repeats the activity GET. A matching root yields an unavailable-response fallback
and preserves authentication; only a current root login-form/principal rejection
permits disposal. Unknown, network, and cancelled validations preserve stored
material. A learning-report-only failure remains partial report coverage under
the existing sync policy; actual authentication rejection still stops the pass.
The network regression also exposed a root-load callback arriving before its
navigation Future settled. Both Futures are now observed together, so an early
load failure reaches fallback without an unhandled asynchronous exception.
The same race was reproduced during initial headless creation; that path now
also observes creation and page completion together. Its regression verifies
saved authentication is retained, the failed view is disposed, and a new view
can restore the session on retry.

The diagnostic `rootLoginForm` records the existing password-input predicate,
including hidden inputs. It is not by itself proof of server-side revocation or
a concurrent-login policy. `rootAccepted` followed by a failing endpoint now
distinguishes endpoint availability from losing the entire school connection.

For the next authorized reproduction, compare reason order before and after
the user's browser login. Distinguish root login-form rejection from unknown
HTML, local view errors, principal mismatch, and an unrelated redirect. A real
server-revoked cookie cannot be repaired by replaying it; do not bypass school
policy, copy browser credentials, or invent automatic SSO authentication.

These changes address verified local recovery weaknesses. The Chrome scenario
has now been reproduced, including the school's visible session-ended response,
but the exact server/SSO setting behind that response remains unverified. The
final local fixes do not repair a session the school no longer accepts.

## Verification checkpoint

The final follow-up passed90 focused session/controller/sync tests, the full
Flutter suite1074 passed/one existing skip, static analysis and diff checking.
Mac/iOS/Android Debug builds and the Android APK signature passed. The two iOS
simulators were updated in place with protected data hashes preserved; native
interactive iOS/Android/Windows authentication remains unverified.

After capturing PID36937's reproduction, the final verified Mac build was
installed in place and relaunched asPID61532. Protected readable files and the
production App Store installation matched before/after hashes. The actual
calendar displays cached LMS rows; a new scoped repository read confirms all28
events with the same25 known completion matches and no duplicates. The school
authentication remains expired; no login was completed during this update.

## Remaining authentication decision

The school explicitly supports the official Coursemos mobile app, but its
public instructions do not establish an external-app grant, callback or data
API contract for Daily.
[School mobile-app instructions](https://ecampus.smu.ac.kr/mod/ubboard/article.php?bwid=98878&id=3).
Moodle's app authentication is separately server-configured; it cannot simply
be inferred from availability of a school web login.
[Moodle mobile authentication](https://docs.moodle.org/311/en/Moodle_app_guide_for_admins#Mobile_authentication).

The homepage's urgent login notice was also checked. It describes an SSO DB
connection error on2025-12-24 and explicitly reports recovery that evening;
it does not explain this Chrome reproduction.
[School notice](https://ecampus.smu.ac.kr/mod/ubboard/article.php?bwid=671541&id=1).
Likewise, the school's simultaneous-content restriction concerns attending
multiple videos, not a published general session-concurrency setting.
[School learning FAQ](https://ecampus.smu.ac.kr/mod/ubboard/article.php?bwid=160029&id=3).

Issue88 stays open. A supported independent app authentication/read API needs
confirmation from school/provider specifications before changing the product
authentication design. No token/grant request, official-app token extraction,
browser-cookie copying, new credential storage or external inquiry was made.
