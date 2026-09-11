#!/usr/bin/env python3
"""Publish Linux packages without replacing any Apple/Android/Windows asset."""
import argparse
import hashlib
import pathlib
import subprocess
import tempfile

REPO = "littlebit0/DailyCalendar"
CHANNEL = "linux-apt"


def gh(*args, **kwargs):
    return subprocess.run(["gh", *args, "--repo", REPO], check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def publish(packages, tag, key):
    # The ordinary release must already exist. Never create an incomplete release.
    gh("release", "view", tag, stdout=subprocess.DEVNULL)
    existing = subprocess.run(["gh", "release", "view", CHANNEL, "--repo", REPO],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if existing.returncode:
        gh("release", "create", CHANNEL, "--prerelease", "--latest=false",
           "--title", "Daily Linux signed APT repository",
           "--notes", "Automatic-update channel for Linux .deb installations. Installers are also available in versioned releases. This prerelease is not a replacement for the latest product release.")
    with tempfile.TemporaryDirectory(prefix="daily-apt-") as temporary:
        directory = pathlib.Path(temporary)
        result = subprocess.run(["gh", "release", "download", CHANNEL, "--repo", REPO,
                                 "--pattern", "*.deb", "--dir", str(directory)], capture_output=True)
        if result.returncode and b"no assets" not in result.stderr.lower() and b"no assets" not in result.stdout.lower():
            raise RuntimeError("Cannot read existing archive packages; refusing to replace indices")
        for package in packages:
            previous = directory / package.name
            if previous.exists():
                if digest(previous) != digest(package):
                    raise ValueError("Published package is immutable; increment the Linux revision")
            else:
                previous.write_bytes(package.read_bytes())
                gh("release", "upload", CHANNEL, str(package))
            # No --clobber: never silently change an existing versioned installer.
            assets = subprocess.check_output(["gh", "release", "view", tag, "--repo", REPO,
                                               "--json", "assets", "--jq", ".assets[].name"], text=True).splitlines()
            if package.name not in assets:
                gh("release", "upload", tag, str(package))
        subprocess.run(["python3", "tool/linux/make-apt-repository.py", str(directory),
                        "--signing-key", key], check=True)
        # GitHub release assets are not atomic. Publish the signed manifest last;
        # an in-flight APT hash mismatch fails closed and retries on the next run.
        for name in ("Packages", "Packages.gz", "Release", "Release.gpg", "InRelease"):
            gh("release", "upload", CHANNEL, str(directory / name), "--clobber")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--packages", type=pathlib.Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--signing-key", required=True)
    args = parser.parse_args()
    packages = sorted(args.packages.rglob("*.deb"))
    if not packages:
        raise SystemExit("No installers supplied")
    publish(packages, args.tag, args.signing_key)
