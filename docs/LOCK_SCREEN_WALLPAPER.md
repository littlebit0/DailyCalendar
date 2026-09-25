# iPhone and iPad Lock Screen Calendar (#66, #83)

## Scope

iPhone, iOS 16 or later; iPad, iPadOS 17 or later. The app's deployment minimum
still applies. This is a locally rendered PNG wallpaper, not a
WidgetKit widget. It does not add wallpaper behavior to macOS, Android, Windows
or Linux. Existing Siri shortcuts, widgets and synchronization are unchanged.

Settings > Lock Screen Calendar opens a native iOS setup screen directly from the
settings root screen, in the Screen & Events group.
The first enable action requests consent because event titles remain visible
while the device is locked. Subsequent OFF/ON changes reuse the existing setup.
Finishing the guide is never recorded as proof of installation or application.

## Data Flow

1. `DailyWallpaperEnabledIntent` reads the device-local enablement and consent.
2. The bundled shortcut continues only when the flag is true.
   `BeginDailyWallpaperUpdateIntent` records an independent attempt ID and
   schedules a two-minute completion-unconfirmed notification before generation.
3. `GenerateDailyWallpaperIntent` requires device authentication and reads
   saved events using the existing native Siri database/recurrence reader.
4. Deleted events and hidden categories are excluded. Current category colors,
   completion, visible Korean holidays, week start and title alignment apply.
5. A portrait PNG is rendered at the phone's native pixel resolution. iPad uses
   the square canvas and common orientation-safe region described below. Continuous
   events occupy one bar per visible week. Dense rows reserve an overflow count;
   small displays may show only the count where titles cannot fit safely.
6. A second opt-in check precedes the system **Set Wallpaper Photo** action.
   Only Lock Screen is selected; Home Screen, Photos and cloud data are not
   written by this automatic workflow. Preview, perspective zoom, smart crop and
   legibility blur are disabled in the supplied workflow.
7. `CompleteDailyWallpaperUpdateIntent` receives that attempt ID only after
   Set Wallpaper finishes. It records system-action completion and removes the
   pending/delivered notification for that ID. It cannot inspect actual pixels.

The guide requests a photo-based Lock Screen as the import configuration. The
user creates the personal automation: App > the correct Daily app > Is Opened
> Run Immediately > DailyCalendar Wallpaper. Daily cannot create that automation
or query its installed/enabled state using a public API.

Automatic updates occur when the user-configured automation runs, not on a
background timer. The image uses the local database at that instant. A remote
restore that finishes later is reflected on the next run; #71's startup-sync
gate is separate work. Opening Settings or previewing does not run the shortcut.
Update Now/Test Now explicitly opens the named shortcut through the public URL
scheme. They do not report wallpaper success merely because the URL opened.

## Layout and Privacy

- The explicit **Save Calendar to Photos** button requests add-only PhotoKit
  access and saves the actual generated PNG. This is not called by preview,
  intents, automatic refresh or merely opening the guide. Denial remains an
  error, not a saved/prepared status. Saved copies can sync according to the
  user's iCloud Photos settings; consent and permission descriptions disclose
  this in all four languages. The app does not read the user's photo library.
- Wallpaper themes are explicitly dark/light, independent of the surrounding
  app's selected theme. Native settings and guides follow the app theme/language.
- Korean, English, Japanese and Traditional Chinese are supported. App Intent
  action names/descriptions also have an iOS string catalog.
- On iPhone, the top 34-52% is reserved according to the vertical-position control; the
  bottom 15% remains free of calendar content. This is not a universal guarantee
  for enlarged iOS clocks, extra widgets, notifications or system zoom. The guide
  asks users to check the actual Lock Screen and adjust position as needed.
- Cache identity includes dates, events, completion, colors, settings, device kind,
  native display dimensions (including both edges of an iPad's square canvas),
  locale, alignment and renderer version. Old PNGs are pruned after generation.
- `Caches/DailyWallpaper` uses atomic writes, complete file protection and backup
  exclusion. Native settings (`daily.wallpaper.settings.v1`) are not Drive sync
  settings. `daily.wallpaper.generatedAt` means generated, **not applied**.
- Reset/logout disables this feature and clears its cache before clearing shared
  settings. Pending generation is invalidated on configuration/reset changes.
- The preview is hidden while inactive. With app lock enabled, backgrounding
  dismisses the native settings form so return goes through Flutter's lock gate.
- OFF stops future shortcut updates but cannot remove an already applied image.
  Full removal clears only wallpaper cache/settings, preserving events, and
  guides the user to delete the iOS automation/shortcut and restore wallpaper.

## iPad Layout and Verification Boundary (#83)

The same settings bridge, consent, App Intents, signed Shortcuts, local event
reader, OFF/re-enable behavior, setup progress, feedback and removal flow serve
iPhone and iPad. No new shortcut actions or imported-shortcut replacement is
required for this extension. The two phone-only guards now accept iPadOS 17+.
Wallpaper settings and generated images remain device-local and outside Drive
sync; reset invalidates pending image generation before clearing the cache.

`DailyWallpaperCanvas` measures the built-in display's native pixels. It does
not identify an iPad model or use the size/orientation of a Split View, Stage
Manager or external-display window. The PNG is square, with each edge equal to
the native display's long edge. This is a deliberate single-image strategy:
App Intents may run without a foreground window, and rotating a Lock Screen
does not trigger Daily to regenerate or apply another wallpaper.

The calendar occupies the intersection of the centered portrait and landscape
crops. Each crop reserves clock/date space above it; landscape also reserves
the left quarter for the usual widget column. The existing position slider
maps to 32-44% of each crop's height. The bottom 10% of portrait and 9% of
landscape remain outside the calendar. These proportional bounds do not promise
avoidance of every enlarged clock, widget configuration or notification stack.

iPad typography scales from the native short edge using a different proportion
than iPhone. A height limit keeps at least two event slots per week even for
six-week months at the slider's lowest position: dense days show an event and
an overflow count. The month model, week start, holiday/completion colors,
current-day emphasis, continuous-event lanes and title alignment are shared.
iPhone framing and type sizes are unchanged. Renderer version 2 invalidates
old images; cache identity also includes device kind and both native edges, so
two iPads with the same long edge but different ratios cannot reuse a layout.

The settings screen displays portrait and landscape crops taken from the
**same actual generated PNG**. They are labeled as crop previews. They do not
show system clocks/widgets or claim to read the Lock Screen. Wallpaper zoom,
repositioning, spatial/depth effects and OS behavior may produce a different
crop; verify both orientations on the device and adjust the photo placement
and calendar position as needed. The supplied shortcut already disables
perspective zoom, smart crop and legibility blur, but that is not proof of the
OS's final composition.

Apple documents that [nativeBounds remains in portrait coordinates](https://developer.apple.com/documentation/uikit/uiscreen/nativebounds),
that [iPad supports Set Wallpaper in personal automations](https://support.apple.com/en-gb/guide/ipad/ipad997d908e/18.0/ipados/18.0),
and that [landscape Lock Screen widgets appear on the left](https://www.apple.com/mideast/ipados/ipados-17/a/pdf/en/iPadOS_All_New_Features_JOEN.pdf).
These references establish the design constraints, not runtime acceptance of
Daily's generated image or a guarantee of centered system cropping.

Host Swift tests cover native pixel examples for mini (1488x2266), base/Air
(1640x2360), Pro 11 (1668x2388 and 1668x2420), Pro 12.9/13 (2048x2732 and
2064x2752), an older 4:3 display (1536x2048), and an arbitrary 1730x2470
display. For every size, 4-6 weeks and seven slider positions are checked for
crop containment, clock/widget margins, readable type bounds and event/overflow
capacity. These are geometry cases, **not physical-device test results**.

The user will perform actual iPad shortcut import/application tests. No shortcut
execution, wallpaper change or personal automation change is authorized for the
agent in this task. Before closing #83, the user must verify the real photo
Lock Screen selection and application, portrait/landscape cropping and clock
overlap, readable dense events, OFF/no-change and re-enable/reuse, and removal
on representative iPad devices. Actual application remains unverified until
that acceptance is supplied.

## Application Feedback (Updated 2026-09-16)

- Closing a shortcut share/import sheet returns to the same step without
  another modal or an installation claim. The user explicitly acknowledges
  adding it, then runs Apply Now and confirms the actual Lock Screen separately.
- Manual Update Now/Test Now uses Shortcuts' public x-callback-url. Error and
  cancel callbacks produce localized notifications; URL success alone remains
  unconfirmed. Unknown/replayed attempt IDs are ignored, and arbitrary error
  payloads are not stored. A native Flutter scene lifecycle plugin consumes
  wallpaper callbacks on warm/cold launch before they reach calendar navigation.
- The update workflow records begin and completion around the real wallpaper
  operation, with its ID also passed to generation for immediate image-error
  reporting. Ordinary preview and standalone generation do not create attempts.
- If no completion reaches Daily within two minutes, iOS is asked to deliver
  an **unconfirmed** notification, not a claim of proven failure. This covers
  interruptions, selection/permission waits and missing/deleted wallpaper after
  monitoring began. If a directly launched automation fails before Begin, Daily
  cannot observe it; Shortcuts' own error remains the available feedback.
- Notification authorization is requested only from explicit manual-test
  actions. Denial does not block wallpaper updates. The settings form preserves
  the result and offers notification settings when alerts are not authorized.
  Focus and other OS delivery policies still apply. OFF/reset clears only
  wallpaper attempt notifications, never event reminders. Attempts contain no
  event titles or image data, expire from history after a day, and are local only.
- A completion receipt means **the system action returned**, not that the user
  is currently viewing that wallpaper. Another Lock Screen or the Home Screen
  may show something else. The supplied shortcut still changes Lock Screen only.

Read-only evidence for the user's 16:42 run on the iPhone 17 simulator:
Shortcuts logged successful Set Wallpaper completion at 16:42:07. The generated
PNG and the selected Photos poster's version-3 Original.png both had SHA-256
`66150d5c5e2c067e365e3bb98ee877db33055ed856d7c5732fc217e54a3ccea9`.
This proves image handoff/storage for that run, not the visible lock-screen
composition. The user was asked whether the missing calendar was on Lock Screen
or Home Screen; that visual symptom remains unconfirmed. No wallpaper, shortcut
library, automation or simulator UI was changed during the investigation.

The updated monitoring workflow must replace the previously imported copy after
the next app update. Keep its name and choose the intended photo Lock Screen
again if requested. App updates do not replace imported Shortcuts. The two
resources were re-signed after temporary 502/503 signing failures; generation
now stages both files before replacing existing resources so a signing error
does not leave only one updated file.

## Shortcut Artifact

Two ready-made signed files are bundled:

- `ios/Runner/Resources/DailyCalendar Wallpaper.shortcut`: update workflow
  for existing/new automations; no setup menus or guide dialogs.
- `ios/Runner/Resources/DailyCalendar Wallpaper Setup.shortcut`: optional
  interactive helper, run manually inside Shortcuts. Never attach this helper
  to the app-open automation.

The main setup has four stages with a single primary action and a separate
explicit user confirmation in each:

1. Photo: save the current calendar PNG, then prepare a Photos Lock Screen.
2. Shortcut: add/replace DailyCalendar Wallpaper and select that photo wallpaper.
3. Verify: run it, inspect the actual Lock Screen, acknowledge that it is visible.
4. Automate (optional): connect the app-open automation in Shortcuts.

The native screen has a compact step indicator, actual calendar preview, a
fixed bottom action area and separate wallpaper options. The options retain
enablement, appearance, vertical position, preview refresh, last generation,
notifications, removal and the legacy helper. The helper is no longer required.
`daily.wallpaper.setup.v2` persists explicit user acknowledgements, not inferred
OS state. Old guide positions do not migrate into success. Visual verification
precedes automation, replacing a shortcut invalidates downstream checks, and
reset clears both old and new progress. Ordinary URL/notification results never
mark the wallpaper as visually confirmed.

Add Shortcut presents the iOS file-sharing interface to open the selected file
in Shortcuts and approve import. There is no fabricated iCloud URL, automatic
file import, or silently installed personal automation.

Two visual walkthroughs show one highlighted control at a time: preparing the
photo wallpaper, and creating the personal automation. They use the actual
calendar image/app name and preserve the current guide position while switching
apps. Tapping an illustrated control advances only the guide, not completion.
They are labeled as a screen guide, not real Settings/Shortcuts controls. No
private Settings URL, system UI overlay or fabricated installation API is used.
The user still creates/selects the active photo Lock Screen in iOS and reviews
its Home Screen setting; only subsequent shortcut updates are Lock-Screen-only.

On 2026-09-15, read-only iOS 26.5 logs showed the simulator's selection query
retrieved one `com.apple.MercuryPoster` configuration and skipped it as non-Photos.
There was no eligible photo Lock Screen to select; the import field did open the
system picker. Creating a photo Lock Screen in Settings is required on that
device. The workflow and its corrected Boolean guards are unchanged by this
guidance fix. Source for the Settings path:
[Apple: Change the wallpaper on iPhone](https://support.apple.com/en-ae/guide/iphone/iph3d267104/ios).

### Guide Inside Shortcuts

`DailyWallpaperSetupIntent` uses public App Intents disambiguation/confirmation
dialogs without opening Daily. Its text follows Daily's Korean, English,
Japanese or Traditional Chinese language setting (system fallback).

- View Connection Steps: names the actual installed app (including Daily Test),
  shows the app-open/immediate-run steps and the exact update shortcut name.
  Continue closes the guide; the user then opens Automation and connects it.
- Test Now: requires existing wallpaper consent and enablement, asks before
  changing the selected Lock Screen, and returns true only after confirmation
  and a second enablement/consent check. The helper then runs the existing
  DailyCalendar Wallpaper shortcut, preserving its selected wallpaper and guards.
  A missing update shortcut or system permission failure remains a Shortcuts
  error; no success state is fabricated. The user checks the Lock Screen.
- Close Guide or View Connection Steps returns false, skipping the update.
  Cancelling a system prompt stops the helper before the update action.

The helper never changes consent, reads events, generates images, registers
automations or records a test as automation installation. Guidance is a prompt
inside Shortcuts, not an overlay on its automation editor. It does not observe
the user's editing steps. System authentication/permission prompts can still
occur during actual updates. Removal instructions cover both shortcut files.

Generate/sign on macOS (does not install or execute it):

```sh
python3 tool/build_wallpaper_shortcut.py
```

Inspect the deterministic unsigned source:

```sh
python3 tool/build_wallpaper_shortcut.py --unsigned /tmp/DailyCalendar-Wallpaper.plist
plutil -p /tmp/DailyCalendar-Wallpaper.plist
python3 tool/build_wallpaper_shortcut.py --setup --unsigned /tmp/DailyCalendar-Wallpaper-Setup.plist
plutil -p /tmp/DailyCalendar-Wallpaper-Setup.plist
```

App Intent descriptors match the project's existing exported Signal shortcut.
Wallpaper action parameters were checked against the local iOS 26.5 system
ActionKit definitions. This serialized workflow format still needs import and
runtime acceptance on supported iOS versions; signing does not prove execution.
Re-sign the bundled files as needed for future distributions. Never include
signing credentials or private files in the repository.

### Conditional Input Repair (2026-09-15)

Shortcuts logs confirmed `ConditionalAction` errors at action indexes 1 and 4:
"Please choose a value for each parameter in this action." The generated
conditions used a bare token attachment where the If action expects
`WFInput = { Type: Variable, Variable: <attachment> }`. Both update guards and
the Setup helper guard now use the iOS editor's Boolean `is true` shape
(`WFCondition = 4`) instead of the old existence check (`100`). The Boolean
producer and PNG producer remain separate; do not select the image or its file
size as the second guard's input. A normalized iOS 26.5 editor-saved fixture
covers all three guards; compiled metadata tests also require Boolean outputs.

The two corrected signed files must be re-imported by the user to replace
already-added copies. Updating Daily alone does not rewrite Shortcuts' library.
Keep the existing names, reselect the intended photo Lock Screen if prompted,
and confirm the automation still references the update shortcut, not Setup.
Do not edit Shortcuts' database or clear the user's wallpaper/automation setup.
Runtime acceptance of the corrected files remains separate from these checks.

### String Parameter Repair and Rendering Boundary (2026-09-16)

Read-only logs for the user's 14:58 run found a second serialization bug in the
monitoring workflow: `updateID` was a bare `WFTextTokenAttachment`. Both String
parameters arrived empty, and the required completion parameter prompted for an
internal ID. The supplied input was not a UUID, but the intent silently returned.

Both parameters now use `WFTextTokenString` with an object-replacement character
and an `attachmentsByRange` ActionOutput. The fixture is normalized from the
working Signal String parameter saved by the actual iOS Shortcuts editor.
The completion parameter is optional to avoid internal-ID prompts, but missing,
unknown, non-shortcut or already-finished IDs throw a localized replace-shortcut
error rather than recording success or guessing the most recent attempt.
Existing Boolean/file token serialization is unchanged. Both resources were
re-signed. The user must replace the previously imported update shortcut.

The same run logged Set Wallpaper success at 14:58:14 followed by a
PhotosPosterProvider snapshot failure and termination at 14:58:15, plus
`FBSceneErrorDomain`/XPC scene update failure. This is evidence of a Simulator
rendering failure after image handoff, not proof of a fix to visible rendering
or a proven cause on a physical iPhone. The app cannot observe actual Lock Screen
pixels through a public API. The Simulator-only troubleshooting note makes that
boundary explicit. Do not reset the user's wallpapers, kill system services or
call private wallpaper APIs to hide it. Real-device display still needs user
acceptance; this turn did not execute/import shortcuts or change wallpaper.

## Automated Verification

```sh
swiftc ios/Runner/DailyWallpaperModel.swift ios/Runner/DailyWallpaperText.swift \
  tool/tests/wallpaper_model_test.swift -o /tmp/daily-wallpaper-model-tests
/tmp/daily-wallpaper-model-tests
./tool/flutter.sh test --no-pub
./tool/flutter.sh analyze --no-pub
DAILY_WALLPAPER_BUILT_APP=build/ios/Debug-iphonesimulator/Runner.app \
  python3 -m unittest discover -s tool/tests -p test_wallpaper_shortcut.py -v
```

Build the booted iPhone 17 with Xcode's `Runner.xcworkspace` / `Runner` scheme,
Debug, `iphonesimulator`, its explicit destination ID, `ONLY_ACTIVE_ARCH=YES`,
`ARCHS=arm64`, and `BUILD_DIR=<repo>/build/ios`. This avoids the existing generic
multi-architecture simulator lipo failure; never install the stale generic path.

The Swift checks cover month/year boundaries, DST, leap days, clipping,
continuous-event lanes, dense/short-display bounds, normalization and translations.
Flutter checks cover iOS-only navigation/channel calls and reset/error behavior.
Python checks validate workflow wiring, guards, Lock-Screen-only parameters,
compiled App Intent metadata and both actual bundled signed files. None of these
checks installs an app, runs a personal automation or changes a wallpaper.

With Xcode 27.0, the generic Flutter simulator build currently fails its lipo
multi-architecture verification. For an Apple Silicon simulator-only check,
use the actual simulator destination with command-line `ARCHS=arm64` and
`ONLY_ACTIVE_ARCH=YES` in xcodebuild; do not change the project's supported
architectures. This path was verified for iPhone 17 on 2026-09-15. Pass the
resulting `build/ios/Debug-iphonesimulator/Runner.app` to the metadata test,
not an older `build/ios/iphonesimulator/Runner.app` export. This does not verify
an Intel simulator build or a distribution archive.

## Required Device Acceptance Before Closing #66

- Import the bundled file on a device without this shortcut, including the
  photo Lock Screen selection question and permissions. Verify the system share
  interface offers the intended Shortcuts import route.
- Follow the photo Lock Screen preparation pages with no eligible wallpaper;
  create a Photos wallpaper manually, return and check that it becomes selectable.
  Test explicit photo save with add-only permission allowed/denied, and confirm
  automation never writes to Photos. Guide navigation must not mark setup done.
  Also check the existing-photo shortcut path, both themes, large text, back
  navigation, import cancellation and help access from later guide steps. These
  steps must not mark a wallpaper as detected or alter consent/home wallpaper.
- Import/run the Setup helper inside Shortcuts in all four languages. Verify
  guide text is readable, Continue leaves the user in Shortcuts, and the helper
  names the installed app correctly. Verify guide/close/cancel never change the
  wallpaper, consent or automation state.
- Test with consent OFF, updates OFF, missing update shortcut, cancelled
  confirmation and denied system permissions. Test Now must use the existing
  update shortcut's selected Lock Screen and still report no automation status.
- Reopen the app guide after leaving/closing it, check its saved step and back
  navigation, and ensure existing automations never show the helper menu.
- Run Test Now with actual events, both themes, short/tall displays, large
  clocks, widgets and dense months; verify PNG framing and title readability.
- Create the app-open automation once, verify it runs, then verify OFF makes no
  wallpaper change and ON resumes without rebuilding the automation.
- Verify month/day rollover, event edits/completion/category changes, locked
  execution, deletion/hidden categories and data-not-ready/error cases.
- Verify app lock after leaving native settings and all removal instructions.
- Verify error/cancel callbacks, no selected photo wallpaper, deleted selected
  wallpaper, permission denial, and interruption lasting over two minutes.
  Check alerts with notifications allowed/denied and foreground/background.
  Confirm real completion removes its timeout alert, stale tokens do not alter
  other attempts, and OFF/reset cancels pending wallpaper warnings only.
- Check cold-start callback routing, explicit post-import acknowledgement and
  replacement of the old malformed String-token shortcut without an ID prompt.
  These new notification/callback paths have build/model/contract coverage,
  not device runtime acceptance. The user performs execution/visual testing.

No device acceptance, app installation, version bump, release, commit/push or
issue closure is implied by a successful build. Issue #66 remains open until
the missing runtime acceptance has been performed.

## Apple References

- [Personal automation](https://support.apple.com/guide/shortcuts/intro-to-personal-automation-apd690170742/ios)
- [Share shortcuts as signed files](https://support.apple.com/en-ca/guide/shortcuts/apdf01f8c054/ios)
- [Run a shortcut with a URL](https://support.apple.com/en-nz/guide/shortcuts/apd624386f42/ios)
- [Shortcuts x-callback-url](https://support.apple.com/guide/shortcuts/apdcd7f20a6f/ios)
- [Local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Shortcuts wallpaper action updates](https://support.apple.com/en-euro/101583)
