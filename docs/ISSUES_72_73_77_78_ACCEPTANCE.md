# Issues 72, 73, 77, 78

## Implemented behavior

- #72: `UpdateFeaturesGate` runs inside the existing startup sync gate, after
  its completion or the user's explicit offline continuation. The catalog in
  `feature_announcements.dart` has stable IDs, introduced versions and platform
  constraints. Confirmation is local in `seenFeatureAnnouncements.v1`, not
  synced to other devices. Skip acknowledges only the displayed feature;
  interruption leaves remaining features pending. Fresh onboarding establishes
  the current catalog baseline. Weather opens its existing settings; wallpaper
  opens existing iOS native setup. Existing feature state is never overwritten.
  Optional package-version lookup times out after three seconds and does not
  block calendar access on failure. Reinstall with removed app data is a fresh
  installation; there is no claim that local acknowledgements survive deletion.
- #73: reuse the existing, optional Apple-only Signal/Siri installation guide.
  Add categories immediately after Siri (after analytics on non-Apple OSes),
  before permissions and account setup. The existing category management screen
  is reused. Use defaults performs no category write. Already-onboarded users do
  not re-enter the initial setup flow.
- #77: place field supports local recommendations, pinning, unpinning, hiding,
  restoring hidden places and disabling automatic suggestions. Pinned entries
  precede source-event frequency, then most recently updated event. Whitespace
  is normalized; unrelated abbreviations are not guessed equivalent. Deleted
  events and duplicate source IDs do not count. Top eight suggestions are shown.
  Management is available from the place field's icon. Preferences are stored in
  `frequentPlaces.v1`, cleared with local account/data reset, never uploaded by
  this feature. Original event data is never modified by ranking or pinning.
- #78: remove initial title and number-dialog autofocus and title validation's
  forced focus. Text fields dismiss focus on outside interaction on touch and
  desktop; picker/dropdown navigation clears the old focus before pushing the
  route. Explicit field taps and keyboard input remain supported.

## User acceptance checks

1. Existing installation: new-feature introduction appears once; skip, restart
   and verify no repeat. Open weather/wallpaper setup without losing old settings.
2. Fresh installation only: Siri on Apple platforms, categories on every OS;
   edit categories or use defaults, then complete permissions and login.
3. Create/edit: select a suggested place; pin a new place, hide a suggestion,
   disable automatic suggestions, close/reopen and confirm persistence.
4. Open create and edit screens: keyboard remains closed. Tap title to type,
   visit category/date/time/repeat settings, and confirm keyboard stays closed
   after returning until an input is tapped. Check memo, URL and place too.

No production version bump, public release, cloud schema change or account
login is required. macOS/iOS/Android test installations are updated only after
verification. Windows/Linux share the Flutter implementation but native builds
and installed behavior must be verified in their own environments.
