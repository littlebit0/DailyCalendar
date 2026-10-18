"""RunnerTests must load the app the matching Runner configuration builds."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROJECT = (ROOT / "macos/Runner.xcodeproj/project.pbxproj").read_text()
APP_INFO = (ROOT / "macos/Runner/Configs/AppInfo.xcconfig").read_text()

RUNNER_TESTS = {
    "Debug": "331C80DB294CF71000263BE5",
    "Release": "331C80DC294CF71000263BE5",
    "Profile": "331C80DD294CF71000263BE5",
}


def test_host(identifier, configuration):
    start = PROJECT.index(f"{identifier} /* {configuration} */ = {{")
    block = PROJECT[start : PROJECT.index("name =", start)]
    return re.search(r'TEST_HOST = "([^"]+)";', block).group(1)


def runner_product_name(configuration):
    """PRODUCT_NAME the Runner app target sets for [configuration] (None: AppInfo.xcconfig)."""
    for match in re.finditer(
        r"= \{\n\t\t\tisa = XCBuildConfiguration;(.*?)\n\t\t\tname = (\w+);", PROJECT, re.S
    ):
        body, name = match.groups()
        # Only the Runner app target's configurations inherit AppInfo.xcconfig.
        if name == configuration and "33E5194F232828860026EE4D" in body:
            product = re.search(r'PRODUCT_NAME = "?([^";]+)"?;', body)
            return product.group(1) if product else None
    raise AssertionError(configuration)


class MacosTestHostTest(unittest.TestCase):
    def test_each_configuration_points_at_its_own_runner_product(self):
        default = re.search(r"PRODUCT_NAME = (.+)", APP_INFO).group(1).strip()
        for configuration, identifier in RUNNER_TESTS.items():
            product = runner_product_name(configuration) or default
            host = test_host(identifier, configuration)
            self.assertEqual(
                host,
                f"$(BUILT_PRODUCTS_DIR)/{product}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{product}",
                configuration,
            )


if __name__ == "__main__":
    unittest.main()
