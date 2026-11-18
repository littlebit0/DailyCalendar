import importlib.util
import pathlib
import struct
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("packager", ROOT / "tool/linux/build-deb.py")
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackagingTests(unittest.TestCase):
    def test_reject_incomplete_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary)
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                packager.build(path, path, "3.4.0-1", "amd64")

    def test_reject_unsafe_version(self):
        with self.assertRaises(ValueError):
            packager.build(ROOT, ROOT, "3.4.0;command", "amd64")

    def test_reject_unknown_architecture(self):
        with self.assertRaises(ValueError):
            packager.build(ROOT, ROOT, "3.4.0-1", "unknown")

    def test_icons_use_standard_hicolor_sizes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            packager.install_icons(root)
            icons = sorted((root / "usr/share/icons/hicolor").glob("*/apps/com.littlebit0.daily.png"))
            sizes = set()
            for icon in icons:
                header = icon.read_bytes()[:24]
                self.assertEqual(header[:8], b"\x89PNG\r\n\x1a\n")
                width, height = struct.unpack(">II", header[16:24])
                self.assertEqual(f"{width}x{height}", icon.parts[-3])
                sizes.add(width)
            self.assertLessEqual({48, 256}, sizes)
            self.assertLessEqual(max(sizes), 512)

    def test_remove_keeps_timer_enablement_for_reinstall(self):
        prerm = (ROOT / "packaging/linux/prerm").read_text()
        self.assertIn("systemctl stop dailycalendar-update.timer", prerm)
        self.assertNotIn("disable --now dailycalendar-update.timer", prerm)
        postinst = (ROOT / "packaging/linux/postinst").read_text()
        self.assertIn("systemctl restart dailycalendar-update.timer", postinst)
        self.assertNotIn("systemctl try-restart", postinst)
        self.assertIn('"$1" = purge', (ROOT / "packaging/linux/postrm").read_text())

    def test_scoped_key_and_no_global_unattended_upgrades(self):
        source = (ROOT / "packaging/linux/dailycalendar.sources").read_text()
        self.assertIn("Signed-By: /usr/share/keyrings/dailycalendar-archive-keyring.asc", source)
        self.assertNotIn("trusted=yes", source)
        updater = (ROOT / "packaging/linux/update").read_text()
        self.assertIn("--only-upgrade --no-remove", updater)
        self.assertIn("APT::Update::Error-Mode=any", updater)
        self.assertNotIn("allow-unauthenticated", updater)


if __name__ == "__main__":
    unittest.main()
