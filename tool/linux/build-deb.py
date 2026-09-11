#!/usr/bin/env python3
"""Package an actual Flutter release bundle; no compilation or host changes."""
import argparse
import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]


def install(source, target, mode=0o644):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    target.chmod(mode)


def build(bundle, output, version, arch):
    if not re.fullmatch(r"\d+\.\d+\.\d+-[1-9]\d*", version):
        raise ValueError("Expected a Debian version such as 3.4.0-1")
    if arch not in ("amd64", "arm64"):
        raise ValueError("Unsupported architecture")
    for relative in ("daily", "lib/libflutter_linux_gtk.so", "lib/libapp.so",
                     "data/flutter_assets/AssetManifest.bin"):
        if not (bundle / relative).is_file():
            raise ValueError(f"Incomplete Flutter release bundle: {relative}")
    with tempfile.TemporaryDirectory(prefix="daily-deb-") as temporary:
        root = pathlib.Path(temporary)
        shutil.copytree(bundle, root / "opt/dailycalendar")
        files = {
            "dailycalendar.desktop": "usr/share/applications/com.littlebit0.daily.desktop",
            "dailycalendar.sources": "etc/apt/sources.list.d/dailycalendar.sources",
            "dailycalendar.pref": "etc/apt/preferences.d/dailycalendar",
            "dailycalendar-archive-keyring.asc": "usr/share/keyrings/dailycalendar-archive-keyring.asc",
            "dailycalendar-update.service": "usr/lib/systemd/system/dailycalendar-update.service",
            "dailycalendar-update.timer": "usr/lib/systemd/system/dailycalendar-update.timer",
            "dailycalendar.tmpfiles": "usr/lib/tmpfiles.d/dailycalendar.conf",
            "dailycalendar-reminders.service": "usr/lib/systemd/user/dailycalendar-reminders.service",
            "dailycalendar-reminders.timer": "usr/lib/systemd/user/dailycalendar-reminders.timer",
        }
        for source, target in files.items():
            install(ROOT / "packaging/linux" / source, root / target)
        for source, target in {
            "launcher": "usr/bin/dailycalendar",
            "update": "usr/lib/dailycalendar/update",
            "reminders.py": "usr/lib/dailycalendar/reminders",
            "postinst": "DEBIAN/postinst",
            "prerm": "DEBIAN/prerm",
            "postrm": "DEBIAN/postrm",
        }.items():
            install(ROOT / "packaging/linux" / source, root / target, 0o755)
        install(ROOT / "artwork/daily-app-icon-source.png",
                root / "usr/share/icons/hicolor/1024x1024/apps/com.littlebit0.daily.png")
        notice = root / "usr/share/doc/dailycalendar/README"
        notice.parent.mkdir(parents=True, exist_ok=True)
        notice.write_text(
            "DailyCalendar: https://github.com/littlebit0/DailyCalendar\n"
            "Third-party license notices are bundled in\n"
            "/opt/dailycalendar/data/flutter_assets/NOTICES.Z\n"
            "Update guide: https://github.com/littlebit0/DailyCalendar/blob/main/docs/LINUX_DISTRIBUTION.md\n")
        # Derive ABI requirements from every packaged ELF, including plugins.
        debian = root / "debian"
        debian.mkdir()
        (debian / "control").write_text(
            "Source: dailycalendar\nSection: utils\nPriority: optional\n"
            "Maintainer: littlebit0 <166241069+littlebit0@users.noreply.github.com>\n\n"
            "Package: dailycalendar\nArchitecture: any\nDescription: Daily calendar\n")
        elfs = []
        for path in (root / "opt/dailycalendar").rglob("*"):
            if path.is_file() and not path.is_symlink():
                with path.open("rb") as stream:
                    if stream.read(4) == b"\x7fELF":
                        elfs.append(path)
        result = subprocess.check_output(
            ["dpkg-shlibdeps", "-O", f"-l{root / 'opt/dailycalendar/lib'}",
             "--ignore-missing-info", *[f"-e{p}" for p in elfs]], cwd=root, text=True)
        dependencies = next(line.split("=", 1)[1] for line in result.splitlines()
                            if line.startswith("shlibs:Depends="))
        dependencies += ", ca-certificates, gpgv, apt (>= 2.0), systemd, util-linux, procps, xdg-utils, python3, libnotify-bin, default-dbus-session-bus | dbus-session-bus, gnome-keyring | kwallet6 | kwalletmanager"
        (root / "DEBIAN/control").write_text(
            f"Package: dailycalendar\nVersion: {version}\nArchitecture: {arch}\n"
            "Maintainer: littlebit0 <166241069+littlebit0@users.noreply.github.com>\n"
            "Section: utils\nPriority: optional\n"
            f"Depends: {dependencies}\n"
            "Homepage: https://github.com/littlebit0/DailyCalendar\n"
            "Description: Daily calendar and tasks\n"
            " Calendar, tasks and Google Drive sync with signed automatic updates.\n")
        (root / "DEBIAN/conffiles").write_text(
            "/etc/apt/sources.list.d/dailycalendar.sources\n"
            "/etc/apt/preferences.d/dailycalendar\n"
            "/usr/share/keyrings/dailycalendar-archive-keyring.asc\n")
        shutil.rmtree(debian)
        output.mkdir(parents=True, exist_ok=True)
        destination = output / f"daily-linux-{version}-{arch}.deb"
        subprocess.run(["dpkg-deb", "--root-owner-group", "--build", "-Zxz",
                        str(root), str(destination)], check=True)
        return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=pathlib.Path)
    parser.add_argument("--output", default=ROOT / "dist/linux", type=pathlib.Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--arch", required=True)
    args = parser.parse_args()
    print(build(args.bundle.resolve(), args.output.resolve(), args.version, args.arch))
