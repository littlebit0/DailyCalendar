# Linux Installation and Updates

## Installation

Target: Ubuntu/Debian graphical desktops with APT, systemd, GTK 3, a Secret
Service keyring and a default browser. `.deb` is not a universal Linux format.
amd64 is built on Ubuntu 22.04 (intended for Ubuntu 22.04+/Debian 12+);
arm64 is built on Ubuntu 24.04 (intended for Ubuntu 24.04+/Debian 13+).
Other distributions and headless/WSL installations are not verified targets.

Download the matching architecture from the
[3.4.0 release](https://github.com/littlebit0/DailyCalendar/releases/tag/v3.4.0),
then install with APT so dependencies are resolved:

```sh
dpkg --print-architecture
sudo apt install ./daily-linux-3.4.0-1-amd64.deb
# ARM64 instead:
sudo apt install ./daily-linux-3.4.0-1-arm64.deb
```

Only install the file matching the computer's architecture. App files reside
in `/opt/dailycalendar`, the launcher is `/usr/bin/dailycalendar`, and the
application menu name is **Daily**. Installation does not launch the app.

## Automatic Updates

First installation enables `dailycalendar-update.timer`. It checks 15 minutes
after boot, then every 6 hours, with up to 30 minutes of random delay. It
updates Daily and required dependencies, not the entire OS. A package hold is
respected. Network/signature/hash failures keep the existing installation.
Running Daily defers the update; the updater never force-closes it. The launcher
holds a shared runtime lock and the updater takes it exclusively, protecting
against a launch/update race. Close Daily before a manual APT upgrade.

```sh
systemctl status dailycalendar-update.timer
journalctl -u dailycalendar-update.service
sudo systemctl start dailycalendar-update.service
sudo systemctl disable --now dailycalendar-update.timer
# Re-enable:
sudo systemctl enable --now dailycalendar-update.timer
```

Upgrades preserve an explicitly disabled timer, source configuration and user
files. Package removal does not delete calendars, settings or credentials.
`apt remove dailycalendar` keeps the source and its public key together for
reinstallation; `apt purge dailycalendar` removes both. Active Daily reminder
timers are disabled on removal without deleting private reminder data.

Installed update configuration:

- `/etc/apt/sources.list.d/dailycalendar.sources`
- `/etc/apt/preferences.d/dailycalendar`
- `/usr/share/keyrings/dailycalendar-archive-keyring.asc`
- `/usr/lib/systemd/system/dailycalendar-update.timer`
- `/usr/lib/dailycalendar/update`

The signed `InRelease` authenticates package indices; SHA-256 checksums in the
indices authenticate downloaded packages. The key is scoped to Daily's source,
not globally trusted. Other package names from this source have negative pin
priority. Initial installation relies on the trusted GitHub download; subsequent
updates use APT signature verification. Never use `trusted=yes` or disable
signature checks to work around errors.

## Platform Scope

- Linux uses the existing calendar and v2 Google Drive schema, unchanged.
- Google login uses the existing desktop OAuth loopback flow and the default
  browser. Tokens use Secret Service storage. Automatic sync does not open login.
- Apple login, Siri, Apple widgets, AlarmKit and native biometric/system unlock
  are not Linux features. Daily's own PIN lock remains available.
- Scheduled notifications use `dailycalendar-reminders.timer` in the logged-in
  user's systemd session. The app enables it during notification initialization.
  It checks every 30 seconds, including after Daily closes. Desktop Do Not
  Disturb still applies. This is not a wake-from-sleep alarm or exact-second timer.
- Private reminder records live in `$XDG_DATA_HOME/dailycalendar/reminders`
  (default `~/.local/share/dailycalendar/reminders`). Calendar content is passed
  over stdin, never command-line arguments. Missed reminders older than five
  minutes expire rather than producing a burst of old notifications.
- Real desktop UI, Google sign-in and notification delivery are separate from
  package/CI verification and must be reported independently.

## Maintainer Releases

`release-linux.yml` builds release bundles for amd64/arm64, derives native ABI
dependencies and creates `.deb` packages. Both builds must succeed before it
publishes Linux assets to the existing product release and signed archive.
Apple, Android and Windows assets are not replaced.

The archive lives in the `linux-apt` **prerelease**, which does not become the
latest product release. Published product releases trigger the workflow. For
releases created by `GITHUB_TOKEN`, which do not trigger further release events,
dispatch the Linux workflow explicitly with the matching tag and revision.
The checkout's `pubspec.yaml` must match that tag.

Debian versions progress as `3.4.0-1`, `3.4.0-2`, then `3.4.1-1`. The suffix is
the Linux package revision, not a Daily display-version change. Published `.deb`
files are immutable: increment the revision for a rebuild. Old packages remain
available. GitHub asset replacement is not atomic; an in-flight APT hash mismatch
fails closed and retries later. The signed manifest is uploaded last.

GitHub encrypted secrets: `LINUX_APT_SIGNING_KEY` and the existing desktop build
configuration `GOOGLE_DESKTOP_CLIENT_SECRET`. Public archive fingerprint:
`1C86509FAC07FB37DA9F0B6EE52E84ACEAE49AD4`.
Keep the private key outside git and back it up securely. Do not regenerate it
for each release; rotation requires a trust transition through the old key.

The isolated CI test checks signed install/upgrade, tampered-signature rejection,
running-app deferral, package holds, disabled-timer preservation, binary identity
and user-file preservation. It does not launch Daily or touch a developer's apps.

References: [Flutter Linux](https://docs.flutter.dev/platform-integration/linux/building),
[APT sources](https://manpages.debian.org/testing/apt/sources.list.5.en.html),
[APT verification](https://manpages.debian.org/testing/apt/apt-secure.8.en.html).
