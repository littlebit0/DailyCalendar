# Android Release Signing

## 3.4.0 Key Replacement

The old GitHub APK private key is no longer available. The user authorized a
new key on 2026-09-07. Keep the package `com.littlebit0.dailycalendar` and the
version `3.4.0` / code `340`; do not substitute a debug-signed APK.

- Key alias: `daily-release-20260907`
- Keystore: `$HOME/.local/share/daily-signing/android-release-20260907/daily-android-release.jks`
- Private configuration: `$HOME/.local/share/daily-signing/android-release-20260907/credentials.json`
- Key directory mode: `0700`; keystore and private configuration: `0600`.
- Local Gradle configuration: ignored `android/key.properties`, mode `0600`.
- GitHub Actions encrypted secrets: `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.

Never commit the private configuration, keystore, passwords, or decoded CI
secrets. Keep the private key outside the repository and temporary build
directories. Reuse this key for future GitHub APK updates; do not generate a
fresh key on each release. GitHub secret values cannot be read back through the
API, so they do not replace a recoverable private-key backup.

## Public Certificate

```text
SHA-1   3A:B4:4A:04:82:7C:B2:18:65:4F:34:C6:77:79:29:1B:25:6D:29:50
SHA-256 42:4C:0B:B7:EE:CC:BB:1D:A6:B2:D3:3E:1E:74:85:96:AF:6E:8D:0F:41:98:30:F9:C3:66:D1:0D:FA:94:70:29
```

A separate Android OAuth client was created in project `234127810480`
(`daily-496913`) on 2026-09-07 using the package and SHA-1 above:

- Name: `Daily Android GitHub APK 20260907`
- Public client ID:
  `234127810480-j8ahr3o9ks7sju3eqdu9q7gt30gdkheo.apps.googleusercontent.com`

Google Cloud confirmed creation. All existing clients for older installations,
the Web client ID, and Drive AppData scopes were left unchanged. This
console-only registration does not require rebuilding or reinstalling the
3.4.0 APK. Google notes that propagation can take five minutes to several
hours. Physical-device Google login and Drive authorization remain unverified;
registration success alone is not proof of successful login.

## Upgrade Limitation

This is not a signing rotation authorized by the old key. The new APK cannot
replace an installed old-key APK, including the public 3.3.1 release. Do not
tell users to uninstall before preserving and verifying their data backup.
Uninstalling removes local data; an APK does not contain that user's database.
No automatic uninstall, application-ID change, or data wipe is part of this
release. New-key versions can update subsequent new-key versions normally.

References: [Android app signing](https://developer.android.com/studio/publish/app-signing)
and [Google Sign-In Android client setup](https://codelabs.developers.google.com/sign-in-with-google-android).
