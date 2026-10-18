"""The search layout must own one CurvedAnimation for the State's lifetime."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / "lib/features/calendar/presentation/month_calendar_page.dart").read_text()
STATE = SOURCE[SOURCE.index("class _PaintOnlySearchLayoutState") :]
STATE = STATE[: STATE.index("\nclass ", 10)] if "\nclass " in STATE[10:] else STATE


class SearchLayoutAnimationLifetimeTest(unittest.TestCase):
    def test_curved_animation_is_created_once_and_disposed(self):
        self.assertEqual(STATE.count("CurvedAnimation("), 1)
        init = STATE[STATE.index("void initState") : STATE.index("void didUpdateWidget")]
        self.assertIn("CurvedAnimation(", init)
        dispose = STATE[STATE.index("void dispose") : STATE.index("void _handleAnimationStatus")]
        self.assertLess(dispose.index("_animation.dispose()"), dispose.index("_controller.dispose()"))

    def test_build_does_not_create_animations(self):
        build = STATE[STATE.index("Widget build") :]
        self.assertNotIn("CurvedAnimation(", build)


if __name__ == "__main__":
    unittest.main()
