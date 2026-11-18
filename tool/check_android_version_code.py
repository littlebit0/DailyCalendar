#!/usr/bin/env python3
"""Fail when Android versionCode does not match the pubspec version (#878).

versionCode has always been the version digits joined (4.2.0 -> 420). That only
stays unique and increasing while minor and patch are single digits, so a
version outside that range is rejected instead of silently reusing a code.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def expected_version_code(version):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:\+\d+)?", version)
    if not match:
        raise ValueError(f"Unsupported pubspec version: {version!r}")
    major, minor, patch = map(int, match.groups())
    if major < 1 or minor > 9 or patch > 9:
        raise ValueError(
            f"{version} does not fit versionCode = major*100 + minor*10 + patch; "
            "choose a new versionCode scheme before releasing it")
    return major * 100 + minor * 10 + patch


def check(pubspec, gradle):
    version = re.search(r"^version:\s*(\S+)\s*$", pubspec, re.MULTILINE)
    code = re.search(r"^\s*versionCode\s*=\s*(\d+)\s*$", gradle, re.MULTILINE)
    if not version or not code:
        raise ValueError("pubspec version or literal Android versionCode not found")
    expected = expected_version_code(version.group(1))
    if int(code.group(1)) != expected:
        raise ValueError(
            f"Android versionCode {code.group(1)} does not match pubspec "
            f"{version.group(1)} (expected {expected})")
    return expected


if __name__ == "__main__":
    try:
        print("Android versionCode", check(
            (ROOT / "pubspec.yaml").read_text(),
            (ROOT / "android/app/build.gradle.kts").read_text()))
    except ValueError as error:
        sys.exit(str(error))
