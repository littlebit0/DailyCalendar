#!/usr/bin/env python3
"""Destructive *ephemeral CI only* APT integration test. Never starts Daily."""
import argparse
import fcntl
import functools
import hashlib
import http.server
import importlib.util
import os
import pathlib
import sqlite3
import subprocess
import tempfile
import threading


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, pathlib.Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(*command, check=True):
    return subprocess.run(command, check=check)


def installed():
    return subprocess.check_output(["dpkg-query", "-W", "-f=${Version}", "dailycalendar"], text=True)


def main(bundle, package):
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("Refusing to modify a non-CI host")
    package = package.resolve()
    version = subprocess.check_output(["dpkg-deb", "-f", str(package), "Version"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="daily-apt-test-") as temporary:
        root = pathlib.Path(temporary)
        root.chmod(0o755)
        archive = root / "archive"
        archive.mkdir()
        old = load("packager", "build-deb.py").build(bundle.resolve(), archive, "0.0.1-1", "amd64")
        (archive / package.name).write_bytes(package.read_bytes())
        gnupg = root / "gnupg"
        gnupg.mkdir(mode=0o700)
        os.environ["GNUPGHOME"] = str(gnupg)
        run("gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase", "",
            "--quick-generate-key", "Daily CI archive", "rsa2048", "sign", "0")
        fingerprint = next(line.split(":")[9] for line in subprocess.check_output(
            ["gpg", "--with-colons", "--list-keys"], text=True).splitlines() if line.startswith("fpr:"))
        key = root / "test-key.asc"
        key.write_bytes(subprocess.check_output(["gpg", "--armor", "--export", fingerprint]))
        load("archive", "make-apt-repository.py").generate(archive, fingerprint)
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(archive))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            run("sudo", "apt-get", "install", "-y", "--no-install-recommends", str(old))
            run("sudo", "systemctl", "disable", "--now", "dailycalendar-update.timer")
            run("sudo", "systemd-analyze", "verify", "/usr/lib/systemd/system/dailycalendar-update.service")
            assert installed() == "0.0.1-1"
            marker = pathlib.Path.home() / ".local/share/com.littlebit0.daily/daily.sqlite"
            marker.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(marker) as database:
                database.execute('CREATE TABLE package_preservation_test (value TEXT)')
                database.execute('INSERT INTO package_preservation_test VALUES (?)', ('keep-calendar-data',))
            before = hashlib.sha256(marker.read_bytes()).hexdigest()
            source = root / "dailycalendar.sources"
            source.write_text(
                f"Types: deb\nURIs: http://127.0.0.1:{server.server_port}/\nSuites: ./\n"
                "Signed-By: /usr/share/keyrings/dailycalendar-archive-keyring.asc\n")
            run("sudo", "install", "-m", "644", str(key), "/usr/share/keyrings/dailycalendar-archive-keyring.asc")
            run("sudo", "install", "-m", "644", str(source), "/etc/apt/sources.list.d/dailycalendar.sources")
            manifest = archive / "InRelease"
            valid = manifest.read_bytes()
            manifest.write_bytes(valid.replace(b"DailyCalendar", b"TamperedArchive"))
            assert run("sudo", "/usr/lib/dailycalendar/update", check=False).returncode != 0
            assert installed() == "0.0.1-1", "Invalid signatures must never update"
            manifest.write_bytes(valid)
            with open("/run/lock/dailycalendar-runtime.lock") as lock:
                fcntl.flock(lock, fcntl.LOCK_SH)
                run("sudo", "/usr/lib/dailycalendar/update")
                assert installed() == "0.0.1-1", "Running-app lock must defer updates"
            run("sudo", "apt-mark", "hold", "dailycalendar")
            run("sudo", "/usr/lib/dailycalendar/update")
            assert installed() == "0.0.1-1", "Respect package holds"
            run("sudo", "apt-mark", "unhold", "dailycalendar")
            run("sudo", "/usr/lib/dailycalendar/update")
            assert installed() == version
            assert pathlib.Path("/opt/dailycalendar/daily").read_bytes() == (bundle / "daily").read_bytes()
            assert hashlib.sha256(marker.read_bytes()).hexdigest() == before
            assert subprocess.run(["systemctl", "is-enabled", "dailycalendar-update.timer"]).returncode != 0
            run("sudo", "apt-get", "remove", "-y", "dailycalendar")
            assert hashlib.sha256(marker.read_bytes()).hexdigest() == before
            print("PASS: signed install/upgrade, bad signature rejection, active-app deferral, hold, disabled timer and user-file preservation. App not launched.")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=pathlib.Path)
    parser.add_argument("--package", required=True, type=pathlib.Path)
    args = parser.parse_args()
    main(args.bundle, args.package)
