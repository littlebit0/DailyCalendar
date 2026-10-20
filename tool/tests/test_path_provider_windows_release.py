import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REAL = (ROOT / "third_party/path_provider_windows/lib/src/path_provider_windows_real.dart").read_text()
WRAPPERS = (ROOT / "third_party/path_provider_windows/lib/src/win32_wrappers.dart").read_text()
PUBSPEC = (ROOT / "pubspec.yaml").read_text()


class KnownFolderPathReleaseTest(unittest.TestCase):
    """#210: the OS string from SHGetKnownFolderPath is released exactly once."""

    def get_path(self):
        start = REAL.index("Future<String?> getPath(String folderID)")
        return REAL[start:REAL.index("String? _getStringValue", start)]

    def test_returned_string_is_freed_with_the_com_allocator_before_the_container(self):
        finally_block = self.get_path().split("} finally {", 1)[1]
        free_string = finally_block.index("CoTaskMemFree(returnedPath.cast())")
        free_container = finally_block.index("calloc.free(pathPtrPtr)")
        self.assertLess(free_string, free_container)
        self.assertIn("calloc.free(knownFolderID)", finally_block)
        # Read before the container is freed, skipped when never written.
        self.assertIn("final Pointer<Utf16> returnedPath = pathPtrPtr.value;", finally_block)
        self.assertIn("if (returnedPath != nullptr)", finally_block)
        self.assertEqual(len(re.findall(r"CoTaskMemFree\(", self.get_path())), 1)

    def test_binding_and_override(self):
        self.assertIn("DynamicLibrary.open('ole32.dll')", WRAPPERS)
        self.assertIn("'CoTaskMemFree'", WRAPPERS)
        self.assertIn("path: third_party/path_provider_windows", PUBSPEC)


if __name__ == "__main__":
    unittest.main()
