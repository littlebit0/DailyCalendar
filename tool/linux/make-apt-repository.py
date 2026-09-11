#!/usr/bin/env python3
"""Create a signed flat APT archive containing real Debian packages."""
import argparse
import os
import pathlib
import re
import subprocess


def generate(directory, signing_key):
    directory = directory.resolve()
    packages = sorted(directory.glob("*.deb"))
    if not packages:
        raise ValueError("No Debian packages to publish")
    for package in packages:
        if not re.fullmatch(r"daily-linux-\d+\.\d+\.\d+-[1-9]\d*-(amd64|arm64)\.deb", package.name):
            raise ValueError("Unexpected package filename")
        name = subprocess.check_output(["dpkg-deb", "-f", str(package), "Package"], text=True).strip()
        if name != "dailycalendar":
            raise ValueError("The archive must contain only dailycalendar")
    env = {**os.environ, "LC_ALL": "C"}
    index = subprocess.check_output(["apt-ftparchive", "packages", "."], cwd=directory, env=env)
    (directory / "Packages").write_bytes(index)
    (directory / "Packages.gz").write_bytes(subprocess.check_output(["gzip", "-n", "-9", "-c"], input=index))
    for filename in ("Release", "InRelease", "Release.gpg"):
        (directory / filename).unlink(missing_ok=True)
    release = subprocess.check_output([
        "apt-ftparchive", "-o", "APT::FTPArchive::Release::Origin=DailyCalendar",
        "-o", "APT::FTPArchive::Release::Label=DailyCalendar",
        "-o", "APT::FTPArchive::Release::Suite=stable",
        "-o", "APT::FTPArchive::Release::Codename=daily",
        "-o", "APT::FTPArchive::Release::Architectures=amd64 arm64",
        "release", "."], cwd=directory, env=env)
    (directory / "Release").write_bytes(release)
    for output, operation in (("InRelease", "--clearsign"), ("Release.gpg", "--detach-sign")):
        subprocess.run(["gpg", "--batch", "--yes", "--local-user", signing_key,
                        "--digest-algo", "SHA256", "--armor", "--output", output,
                        operation, "Release"], cwd=directory, check=True)
    subprocess.run(["gpg", "--batch", "--verify", "InRelease"], cwd=directory, check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--signing-key", required=True)
    args = parser.parse_args()
    generate(args.directory, args.signing_key)
