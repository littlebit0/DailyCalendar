# SSO expiration and invalidation research — 2026-09-29

Scope: public primary sources and current Daily source. No product changes,
login submission, authenticated school requests, token grant or cookie export.

## App-token route investigation: public checks on 2026-09-29

The leading concrete candidate is school-issued service-token authentication
through `/login/token.php`, followed by `/webservice/rest/server.php` reads.
Both endpoints respond on SMU. This establishes route presence, NOT successful
issuance, external-client eligibility, Coursemos's exact service contract, token
lifetime, required data coverage, or browser coexistence.

All checks below were anonymous, without credentials, cookies or tokens, with
redirect following disabled. No grant was issued and no login was submitted.

| Public request on `https://ecampus.smu.ac.kr` | Observed response | Evidence limit |
| --- | --- | --- |
| GET `/login/token.php?appsitecheck=1` | HTTP200 JSON, `필수 매개변수 (username) 누락` | Token route responds; service availability is still unknown. |
| POST `/lib/ajax/service.php?nosessionupdate=1`, requesting `tool_mobile_get_public_config` with empty arguments | HTTP200 JSON, `필수 매개변수 (sesskey) 누락` | No public configuration obtained. Explains the earlier unexpected response envelope. |
| GET `/webservice/rest/server.php`, no arguments | HTTP200 XML error `invalidtoken` | Token-checking REST route responds; no authorized data read. |
| GET `/admin/tool/mobile/launch.php`, no arguments | HTTP404 | Standard modern browser-to-app route absent at this exact URL. |
| GET `/local/mobile/check.php?service=moodle_mobile_app` | HTTP404 | Legacy additional-features check route absent at this exact URL. |

Safe response metadata is in `work/issues-87-88/app-auth-route-public-check-20260929.json`,
`app-auth-route-presence-20260929.json`, and
`app-auth-legacy-public-check-20260929.json`. Exact public error messages are
recorded above; no response stack traces, session identifiers or secrets retained.

### What the official implementations establish

- Moodle documents `username`, `password`, and service shortname for token
  issuance. Its official app sends these in an HTTP POST body to
  `/login/token.php`. The built-in mobile service name is `moodle_mobile_app`;
  it is a documented candidate, NOT a confirmed SMU/Coursemos service name.
  https://docs.moodle.org/dev/Creating_a_web_service_client#How_to_get_a_user_token
  https://github.com/moodlehq/moodleapp/blob/main/src/core/services/sites.ts
- The reference token endpoint sets `NO_MOODLE_COOKIES`. The older reference
  parses required credentials before checking whether web services are enabled:
  therefore SMU's missing-username response cannot prove enablement. Current
  reference versions have a special `appsitecheck` response; SMU did not return
  that response. These differences do not establish its installed version.
- Reference issuance can reuse a valid token for the same user and service.
  A web-independent token is not necessarily a newly issued Daily-only token.
  Separate client scope/revocation may require a separately configured service.
  The old reference's twelve-week duration is NOT SMU's confirmed lifetime.
  https://github.com/moodle/moodle/blob/MOODLE_27_STABLE/login/token.php
  https://github.com/moodle/moodle/blob/MOODLE_405_STABLE/login/token.php
- `core_webservice_get_site_info` is a read function providing site/user and
  available-function information. If authorized issuance later succeeds, use it
  to verify identity and discover allowed reads before fetching calendar data.
  Standard function definitions do not prove custom Coursemos learning-time or
  completion data is available through the school's service.
  https://github.com/moodle/moodle/blob/MOODLE_27_STABLE/lib/db/services.php

### Remaining decisive verification, before product implementation

1. Establish the school's usable service shortname and whether native token
   issuance works with the user's authentication method, including SSO/MFA.
2. In a separately scoped user-entered authentication test, check initial grant,
   Chrome login after grant, and grant reissuance while Chrome remains logged in.
   The school's custom authentication can differ from Moodle reference code.
3. Inspect only required read capabilities, token-expiry metadata when exposed,
   and renewal behavior. Keep credential values out of logs and reports.
4. Check multi-device behavior and actual retention over time. Google-account
   linkage and secure credential portability need a separate reviewed design;
   no permission to upload tokens to Drive or deploy a backend is inferred.

No public official source found in this investigation establishes the actual
Coursemos app's private service name or issuance contract. Coursemos messaging
and search developer APIs are different products and their token durations must
not be presented as student-LMS lifetimes. No official app binary extraction,
TLS interception, token grant, product-code edit, build or install was performed.

## User's clarified acceptance criteria

- Google-account-linked LMS integration usable across devices, including actual
  new LMS data synchronization, not merely previously cached calendar rows.
- External browser LMS login/use must not disconnect Daily. This is the highest
  priority and must be tested alongside renewal and multiple-device behavior.
- Reciprocal requirement: Daily login, re-login and automatic renewal must not
  terminate an existing browser session; another Daily device must not terminate
  existing Daily devices. Independent token lifetime alone does not prove this:
  the initial issuance/reissuance login flow must also preserve other sessions.
- Several-day reauthentication is tolerable when necessary; maximize the
  supported login continuity, including automatic renewal where available.
  No precise retention duration is yet established or promised.
- Current code already scopes academic/LMS settings and event sync to the
  account; school authentication material is in device-local secure storage.
  Sharing settings is not proof of portable LMS authorization.
- Browser-companion and calendar-only alternatives do not independently meet
  this complete target. Do not choose them as the main solution without a new
  user decision. Cross-device auth design must follow actual school support;
  uploading cookies or refresh tokens to Drive is not an assumed solution.

## Revised options under reciprocal coexistence — research only

1. Existing browser authorization plus independent app token. Standard Moodle's
   mobile launch route can use an existing authenticated browser session and
   return a service token to the app. An external browser flow can reuse login
   state; opening a browser alone does not expose cookies or grant Daily API
   access. School-enabled service, callback acceptance, required API coverage,
   both directions of session coexistence and reissuance must all be verified.
   Moodle's token lifetime is administrator-configurable; do not promise its
   reference default as the school lifetime. Not all SSO is OAuth/AppAuth.
   https://github.com/moodle/moodle/blob/MOODLE_405_STABLE/admin/tool/mobile/launch.php
   https://github.com/moodle/moodle/blob/MOODLE_405_STABLE/lib/external/classes/util.php#L339-L395
   https://www.rfc-editor.org/rfc/rfc8252.html#section-4
   https://docs.moodle.org/405/en/Moodle_app_guide_for_admins#Web_services_token_duration
2. Google-account-linked backend connector holding a school-permitted app grant.
   This is a deployment layer combined with option1 or3, not another way around
   server invalidation. One connector owns renewal and serves all Google-linked
   devices without a new school login per device. Verify Google ID tokens and
   identify the account by stable `sub`; current email-scoped records would need
   a reviewed migration, not a silent identity switch. Preserve Drive v2 calendar
   storage/sync; the connector's temporary data/credential handling and any
   server-side Drive access require an explicit architecture decision. Costs,
   operational responsibility and server credential custody are new scope.
   https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
   https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2
3. School/Coursemos-supported read-only external service or connector. Standard
   Moodle lets administrators expose selected service functions and issue scoped
   user tokens with expiry/IP restrictions. School support must cover Coursemos
   progress/submission data and authentication isolated from web-login eviction,
   including grant renewal. This may be configuration of existing APIs rather
   than developing a whole new API; custom data may need vendor work. No school
   contact or configuration changes are authorized by this research request.
   https://docs.moodle.org/405/en/Using_web_services#Creating_a_custom_external_service
4. Preserve Daily's own SSO state and obtain a new LMS session when only the LMS
   session expires. Lower-impact diagnostic candidate, NOT a proven solution:
   if the IdP invalidates Daily on Chrome login or reissue invalidates Chrome,
   it fails the reciprocal requirement. Private-store persistence alone cannot
   fix global server session replacement, and does not solve cross-device auth.
5. Browser companion transfers normalized report data via Native Messaging,
   then existing Drive sync distributes events. It avoids creating a second
   LMS login but depends on an available authenticated browser and does not
   independently satisfy standalone cross-device collection/long-term auth.
   Treat as optional fallback requiring user acceptance of that limitation.
   https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging

Recommendation: first establish option1's issuance AND renewal coexistence plus
data coverage; option2 best matches the single Google-linked connection across
devices if the school permits backend use of the grant. If external service is
not enabled, option3 is the supported path. Option4 can be tested before major
architecture work but cannot be adopted merely because a one-off retry works.
Do not count a backend replaying web cookies, copying tokens into Drive, shorter
polling or longer local cookie expiry as a fix for server-side replacement.
No option has yet passed live bidirectional or multi-day coexistence tests.

## New school-specific evidence

A fresh unauthenticated GET of https://smsso.smu.ac.kr/Login.do returned HTTP200.
Visible Korean notice includes a one-PC/one-user restriction and says a new
login in another PC/browser automatically logs out the previously logged-in
browser. The surrounding notice also discusses course registration. This is
direct evidence that the school publicly describes duplicate-login invalidation;
it does not expose the exact e-Campus enforcement configuration, timeout values
or token format. The browser tool also retrieved the English version of the
same notice. No anonymous cookies or session identifiers were persisted.

Fresh unauthenticated e-Campus login HTML still has POST forms to
`/login/index.php` and `/exsignon/sso/sso_idp_login.php`. Only method and action
paths were reported; forms were not submitted. The eXSignOn vendor's indexed
product page describes SAML support and duplicate-login prevention. Direct
vendor-page fetches failed; this is indexed product evidence, not proof of the
school's installed version or protocol. Official source:
https://techdom.tomatosystem.co.kr/p/00021/

Combined with the user-confirmed Daily-then-Chrome sequence and the actual
school session-ended page, duplicate-login invalidation is now the strongest
working explanation. It remains a hypothesis about the exact mechanism.
The 34 seconds between Daily login and rejection is an observation, NOT a
configured 34-second token lifetime. Last source success was only about16
seconds before rejection; controller ready acknowledgments are not new requests.

## SSO layers and expiration criteria

SSO is a login arrangement, not one token format. The central identity provider
session, one-time login assertion/ticket and the LMS application session can
have different lifetimes. The application must determine which layer failed.

1. Fixed token lifetime: OAuth responses can specify `expires_in`; OIDC ID
   tokens use `exp`. Access-token and ID-token roles differ. The OIDC standard
   explicitly separates ID-token expiry from the authenticated session lifetime.
   https://www.rfc-editor.org/rfc/rfc6749.html#section-5.1
   https://openid.net/specs/openid-connect-core-1_0.html#IDToken
2. Inactivity timeout: server ends a session after qualifying activity stops.
   Moodle documents an administrator-controlled session timeout. Which requests
   refresh it matters; background calls are not universally qualifying activity.
   https://docs.moodle.org/405/en/Session_handling#Timeout
3. Absolute lifetime: elapsed time since creation can expire a session even
   while actively used. Periodic requests cannot extend an absolute deadline.
   https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#absolute-timeout
4. Replacement/duplicate login: a site can terminate an older session at a new
   login, independently of remaining time. The school notice is directly relevant.
   https://smsso.smu.ac.kr/Login.do
5. Rotation/reuse: a replaced session identifier or OAuth refresh token can
   become unusable. OAuth refresh-token replay detection can revoke the active
   token chain. This is a general criterion; no OAuth refresh-token flow was
   established for Daily's school login.
   https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2
6. Logout/security event: password changes or identity-provider logout may
   revoke OAuth refresh tokens according to server policy. Not every logout
   necessarily revokes every token across systems.
   https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2
7. Reauthentication age: OIDC `max_age` can require active reauthentication;
   it is not the access token's expiry field. `prompt=none` can reuse existing
   authentication only if the provider can fulfill the request without UI.
   https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest
8. Client cookie loss/expiry or binding mismatch can make a valid server session
   inaccessible; this is not proof the server token reached a time deadline.
   Cookie expiry metadata alone does not establish server-session validity.
   https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html

Protocol comparisons (not assertions about SMU deployment): SAML uses assertion
validity conditions and can separately express session expiry; CAS service
tickets are one-use while ticket-granting tickets have their own expiration
policy. Neither implies OAuth refresh-token availability.
https://docs.oasis-open.org/security/saml/v2.0/saml-core-2.0-os.pdf
https://docs.oasis-open.org/security/saml/v2.0/sstc-saml-approved-errata-2.0.html
https://apereo.github.io/cas/development/protocol/CAS-Protocol-Specification.html
https://apereo.github.io/cas/development/ticketing/Configuring-Ticket-Expiration-Policy-TGT.html

There is no universal SSO expiry duration. Example/default durations from a
reference product cannot be reported as the school's configured values.

## Current Daily recovery gap and next discriminating investigation

`lms_web_session.dart` persists only `MoodleSession`/`MoodleSession_*` cookies
in `_authenticationCookies()` and restores that snapshot. `recoverAuthentication()`
validates the live LMS root and tries the snapshot; it explicitly does not enter
an SSO route or obtain a fresh authentication grant. Apple WebViews are private,
nonpersistent and do not share browser cookies. Thus this is session restoration,
not a complete SSO renewal implementation; a still-valid IdP session could in
principle reestablish an expired LMS session, but that path has not been tested.

Before ruling out the current approach, distinguish LMS-only invalidation from
central SSO-session invalidation in Daily's own private browser. Record only
nonsecret status, origin/path, times, cookie presence/expiry and fixed error
classifications; do not persist full query strings, cookie/token values or raw
authentication responses. Test whether the school-supported SSO return flow
can obtain a new LMS session without user interaction, and whether doing so
invalidates Chrome. This is a proposed future auth experiment, not performed
by this research. If it works without replacing Chrome, renewal is a candidate;
if it invalidates Chrome or needs fresh credentials, repetitive silent login is
not a coexistence solution. Then app-specific auth or the browser companion
remains the appropriate alternative described in ISSUE_88_SESSION_EVIDENCE.md.
