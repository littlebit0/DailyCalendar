#!/usr/bin/env python3
"""Prepared, not executed by the preparation agent.

Default inspection is read-only. --apply performs one already-verified test-app
update, only after the caller supplies the exact inspected artifact digest.
Never boots, stops, launches, uninstalls or clears any app/device. Never runs a
Shortcut or changes a wallpaper. The caller must stop the test app beforehand.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tarfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/university-expansion"
UDID = os.environ.get("DAILY_SIMULATOR_UDID", "BF524643-403E-4212-ACB7-621E11279532")
IOS_ID = "com.littlebit0.daily"
MAC_ID = "com.littlebit0.daily.test"
ANDROID_ID = "com.littlebit0.dailycalendar"
MAC_INSTALLED = Path.home() / "Applications/Daily Test.app"
STORE = Path("/Applications/Daily.app")
ADB = ROOT / "work/android-sdk/platform-tools/adb"
ADBC = [str(ADB), "-s", "emulator-5554"]
ENV = dict(os.environ, JAVA_HOME=str(ROOT / "work/android-toolchain/jdk/Contents/Home"))


def run(args, *, allowed=(0,)):
    result = subprocess.run([str(x) for x in args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=ENV)
    if result.returncode not in allowed:
        # Avoid printing subprocess output containing account data/build defines.
        raise RuntimeError(f"Command failed: {Path(str(args[0])).name}; code={result.returncode}")
    return result.stdout


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def manifest(path):
    path = Path(path)
    if not path.exists():
        return {}
    return {str(p.relative_to(path)): sha(p) for p in sorted(path.rglob("*"))
            if p.is_file() and not p.is_symlink()}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def app_digest(path):
    return digest(manifest(path))


def copy(src, dst):
    run(["ditto", src, dst])


def save(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True))
    Path(path).chmod(0o600)


def info(path, platform):
    file = Path(path) / ("Contents/Info.plist" if platform == "macos" else "Info.plist")
    return plistlib.loads(file.read_bytes())


def verify_apple(path, platform):
    expected = MAC_ID if platform == "macos" else IOS_ID
    details = info(path, platform)
    if details.get("CFBundleIdentifier") != expected:
        raise RuntimeError("Unexpected bundle ID")
    run(["codesign", "--verify", "--deep", "--strict", path])
    return details


def app_container(kind):
    return Path(run(["xcrun", "simctl", "get_app_container", UDID, IOS_ID, kind]).decode().strip())


def ensure_stopped(platform):
    if platform == "android":
        if run(ADBC + ["shell", "pidof", ANDROID_ID], allowed=(0, 1)).strip():
            raise RuntimeError("Android test app is running; caller must stop it before backup")
        return
    process_args = run(["ps", "-axo", "args="]).decode()
    marker = str(MAC_INSTALLED / "Contents/MacOS/") if platform == "macos" else str(app_container("app")) + "/"
    if any(line.startswith(marker) for line in process_args.splitlines()):
        raise RuntimeError("Apple test app is running; caller must stop it before backup")


def android_files(payload):
    with tarfile.open(fileobj=io.BytesIO(payload)) as tf:
        return {m.name.removeprefix("./"): hashlib.sha256(tf.extractfile(m).read()).hexdigest()
                for m in tf.getmembers() if m.isfile()
                and m.name.removeprefix("./").split("/")[0]
                in ("databases", "shared_prefs", "files", "app_flutter")}


def android_data():
    return run(ADBC + ["exec-out", "run-as", ANDROID_ID, "tar", "-cf", "-", "."])


def android_package_path():
    lines = run(ADBC + ["shell", "pm", "path", ANDROID_ID]).decode().strip().splitlines()
    if len(lines) != 1 or not lines[0].startswith("package:"):
        raise RuntimeError("Expected one existing test APK; do not install into an empty cold-boot state")
    return lines[0][len("package:"):]


def require_equal(before, after, label, ignored=()):
    changes = sorted(k for k in set(before) | set(after)
                     if before.get(k) != after.get(k) and k not in ignored)
    if changes:
        raise RuntimeError(f"{label} changed unexpectedly; {len(changes)} file(s). Backup retained, no restore attempted")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("macos", "ios", "android"))
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-artifact-digest")
    args = parser.parse_args()
    defaults = {
        "macos": ROOT / "build/macos/Build/Products/Debug/Daily Test.app",
        "ios": Path.home() / "Library/Developer/Xcode/DerivedData/Runner-erkgopnohejsmsejvraojecbsyqk/Build/Products/Debug-iphonesimulator/Runner.app",
        "android": ROOT / "build/app/outputs/flutter-apk/app-debug.apk",
    }
    artifact = (args.artifact or defaults[args.platform]).resolve()
    if not artifact.exists():
        raise RuntimeError("Build artifact missing")
    if args.platform == "android":
        run([ROOT / "work/android-sdk/build-tools/36.0.0/apksigner", "verify", artifact])
        badging = run([ROOT / "work/android-sdk/build-tools/36.0.0/aapt2", "dump", "badging", artifact]).decode()
        package = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
        if not package or package.group(1) != ANDROID_ID:
            raise RuntimeError("Unexpected APK package ID")
        artifact_hash = sha(artifact)
        avd = run(ADBC + ["emu", "avd", "name"]).decode().splitlines()[0]
        if avd != "Daily_Pixel_9_API_36":
            raise RuntimeError("Unexpected Android emulator")
        android_package_path()
    else:
        verify_apple(artifact, args.platform)
        artifact_hash = app_digest(artifact)
        if args.platform == "ios":
            verify_apple(app_container("app"), "ios")
        else:
            verify_apple(MAC_INSTALLED, "macos")
    if not args.apply:
        print(json.dumps({"platform": args.platform, "artifactDigest": artifact_hash,
                          "signatureValid": True, "installed": False}, indent=2))
        return
    if args.expected_artifact_digest != artifact_hash:
        raise RuntimeError("--apply requires the exact artifact digest from the verified build inspection")
    ensure_stopped(args.platform)
    os.umask(0o077)
    backup = OUT / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + "-" + args.platform)
    backup.mkdir(parents=True, mode=0o700)
    store_before = manifest(STORE)
    if not store_before:
        raise RuntimeError("App Store installation was not found; inspect environment before updating")
    save(backup / "app-store-manifest.json", store_before)
    report = {"platform": args.platform, "artifactDigest": artifact_hash, "appLaunched": False}
    if args.platform == "macos":
        support = Path.home() / "Library/Application Support" / MAC_ID
        prefs = Path.home() / "Library/Preferences" / (MAC_ID + ".plist")
        before = manifest(support)
        prefs_before = sha(prefs) if prefs.exists() else None
        copy(MAC_INSTALLED, backup / "previous.app")
        if support.exists():
            copy(support, backup / "support")
        if prefs.exists():
            copy(prefs, backup / "preferences.plist")
        save(backup / "data-manifest.json", {"support": before, "preferences": prefs_before})
        stage = MAC_INSTALLED.with_name("Daily Test.timetable-pending.app")
        previous = MAC_INSTALLED.with_name("Daily Test.timetable-previous.app")
        if stage.exists() or previous.exists():
            raise RuntimeError("Pending/previous install exists; inspect before proceeding")
        copy(artifact, stage)
        verify_apple(stage, "macos")
        if app_digest(stage) != artifact_hash:
            raise RuntimeError("Staged artifact changed")
        MAC_INSTALLED.rename(previous)
        try:
            stage.rename(MAC_INSTALLED)
        except BaseException:
            previous.rename(MAC_INSTALLED)
            raise
        verify_apple(MAC_INSTALLED, "macos")
        if app_digest(MAC_INSTALLED) != artifact_hash:
            raise RuntimeError("Installed artifact mismatch")
        require_equal(before, manifest(support), "macOS app data")
        if prefs_before != (sha(prefs) if prefs.exists() else None):
            raise RuntimeError("macOS preferences changed")
        previous.rename(backup / "previous-installed.app")
        report["protectedFiles"] = len(before) + int(prefs_before is not None)
        report["osProtectedContainer"] = "Untouched; not readable in prior verified workflow"
    elif args.platform == "ios":
        data = app_container("data")
        before = {k: v for k, v in manifest(data).items()
                  if k.startswith(("Library/Application Support/", "Library/Preferences/", "Documents/"))}
        if UDID != "409E594D-39B0-4AB0-B7B1-EFC93888BA13" and (not before or "Library/Application Support/daily.sqlite" not in before):
            raise RuntimeError("Expected iOS database is missing; inspect data before updating")
        copy(app_container("app"), backup / "previous.app")
        copy(data, backup / "data")
        save(backup / "data-manifest.json", before)
        run(["xcrun", "simctl", "install", UDID, artifact])
        installed = app_container("app")
        verify_apple(installed, "ios")
        if app_digest(installed) != artifact_hash:
            raise RuntimeError("Installed artifact mismatch")
        after = {k: v for k, v in manifest(app_container("data")).items()
                 if k.startswith(("Library/Application Support/", "Library/Preferences/", "Documents/"))}
        require_equal(before, after, "iOS app data")
        report["protectedFiles"] = len(before)
    else:
        run(ADBC + ["pull", android_package_path(), str(backup / "previous.apk")])
        payload = android_data()
        (backup / "data.tar").write_bytes(payload)
        before = android_files(payload)
        if not before:
            raise RuntimeError("Empty Android protected data; confirm quick-boot snapshot was loaded")
        save(backup / "data-manifest.json", before)
        response = run(ADBC + ["install", "-r", "-t", str(artifact)])
        if b"Success" not in response:
            raise RuntimeError("Android installer did not confirm success")
        run(ADBC + ["pull", android_package_path(), str(backup / "installed.apk")])
        if sha(backup / "installed.apk") != artifact_hash:
            raise RuntimeError("Installed APK mismatch")
        payload_after = android_data()
        (backup / "data-after.tar").write_bytes(payload_after)
        after = android_files(payload_after)
        # AndroidX ProfileVerifier records package lastUpdateTime here. Prior
        # javap inspection confirmed this metadata is not a user setting.
        ignored = ("files/profileInstalled",)
        require_equal(before, after, "Android app data", ignored=ignored)
        report["protectedFiles"] = len([k for k in before if k not in ignored])
        report["runtimeMetadataChanges"] = [k for k in ignored if before.get(k) != after.get(k)]
    require_equal(store_before, manifest(STORE), "App Store bundle")
    ensure_stopped(args.platform)
    report.update(dataPreserved=True, appStoreUnchanged=True, installed=True)
    save(backup / "verification.json", report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
