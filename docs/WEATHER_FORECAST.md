# Weather Forecast (#64)

## Scope

Calendar forecast display is implemented for the shared iOS, Android, macOS,
Windows and Linux app. This does not add weather notifications, change the
manual weather memo stored on individual events, or modify the sync schema.
Issue #64 explicitly permits forecast display before the notification stage.

Settings > Screen & Calendar > Weather forecast contains an opt-in display
switch, optional current-location switch, and offline Korean-region search.
The feature is off by default. Monthly date cells have a compact icon and
temperature (or rain probability at 50% or above); week headers show a summary;
day detail shows condition, official daily low/high and precipitation chance.
Very short monthly rows omit the weather row to preserve event space.
Past dates, unavailable dates and expired forecasts have no weather content.
Dates are Korean forecast dates, even when the device timezone is elsewhere.

## Source and Cache

- KMA XML/RSS service: https://www.weather.go.kr/plus/rss.jsp
- Grid endpoint: `https://www.kma.go.kr/wid/queryDFS.jsp?gridx={x}&gridy={y}`.
  Actual responses were checked with the app's XML parser, not only an HTTP
  status check. No API key, private endpoint or additional server is used.
- Offline region index: KMA's 2026 Q2 workbook, published 2026-07-01.
  See `assets/weather/SOURCE.md` and `tool/import_kma_regions.py`.
- The public feed currently provides three-hour periods. Forecast horizon and
  availability are determined from each response, not assumed or fabricated.
- Refresh on startup/resume and at three-hour intervals while foregrounded;
  midnight also invalidates day summaries. Fresh cache suppresses network work.
  Repeated requests are coalesced. Off/background stops scheduled requests.
- At most four grid caches are retained locally. Forecasts older than 12 hours
  from issuance are hidden, including cached forecasts during service errors.
  The `-999` missing-temperature sentinel is never rendered as a temperature.
- Regional changes and disabling invalidate old in-flight responses. Failed
  requests keep valid cached data; settings expose errors and explicit retry.
- KMA attribution is visible in settings and day details, with accessible
  attribution on compact summaries. Public RSS availability may change; verify
  with `dart run tool/check_kma_forecast.dart [region-code]` before release.

## Location and Privacy

- Manual region selection does not request location permission.
- Only explicitly enabling current location or pressing Retry may request a
  permission dialog. Startup/resume never requests a new permission.
- Native approximate location is used only to match an official nearby region;
  neither raw coordinates nor account identity is sent by Daily to KMA.
  Requests send the selected region's grid over HTTPS. Network services still
  receive the client's IP address as with any network request.
- Out-of-coverage/very inaccurate locations fall back to the chosen manual
  region, or show a settings notice if none is selected.
- Weather settings/cache are device-local (`weather.settings.v1` and
  `weather.cache.v1` in SharedPreferences), outside AppSettings/Drive export.
  Local account reset/logout clears them and invalidates pending results.
- iOS uses When In Use permission; Android requests coarse location only.
  macOS adds the sandbox location entitlement. No background-location service,
  persistent tracking, analytics event or server location history is added.
- Windows uses the geolocator plugin and MSIX location capability.
- Linux uses GeoClue with `com.littlebit0.daily`, matching the installed desktop
  file. Automatic refresh requires an existing location permission-store grant.
  Desktops unable to expose that grant require an explicit Retry for location;
  manual forecasts remain available. GeoClue is an optional .deb recommendation.

Before distributing this feature, review privacy-policy/store disclosures for
optional approximate location and the KMA network service. This task does not
publish store metadata, installers or releases.

## Verification Boundary

Unit tests cover parsing, date boundaries, missing data, region coverage, cache,
request coalescing, permissions, stale responses, failures and local reset.
Widget tests cover narrow/wide layouts, large text and all four app languages
in both themes. Build checks do not establish actual-device permission behavior.
User GUI acceptance and Windows/Linux native execution remain separate checks.
