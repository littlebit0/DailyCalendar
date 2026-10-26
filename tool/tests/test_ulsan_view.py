import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('ulsan_view', ROOT / 'tool/timetable/ulsan_view.py')
view = importlib.util.module_from_spec(spec)
spec.loader.exec_module(view)
P = view.P


def select(name, options, selected):
    items = ''
    for value, label in options:
        mark = 'selected="selected" ' if value == selected else ''
        items += '<option ' + mark + 'value="' + value + '">' + label + '</option>'
    return '<select name="' + P + name + '">' + items + '</select>'


def page(college='11', hagbu=None, year='2026', term='2', viewstate=True, colleges=True, sosog=()):
    parts = []
    if viewstate:
        parts.append('<input type="hidden" name="__VIEWSTATE" value="x" />')
    parts.append(f'<input type="text" name="{P}imedYy" value="{year}" />')
    parts.append(select('ddlHaggi', [('1', '1학기'), ('2', '2학기')], term))
    if colleges:
        parts.append(select('ddlDaehag', [('11', '공과대학'), ('12', '교양대학')], college))
    if hagbu is not None:
        parts.append(select('ddlHagbu', [('111', '기계'), ('112', '전기')], hagbu))
    parts.append(select('ddlSosog', [(v, v) for v in sosog], sosog[0] if sosog else ''))
    return '<html><body><form>' + ''.join(parts) + '</form></body></html>'


class UlsanViewTests(unittest.TestCase):
    def test_a_normal_navigation_response_passes(self):
        view.check_navigation(page('11'), '11')
        view.check_navigation(page('11', hagbu='112', sosog=('a',)), '11', '112')

    def test_a_college_without_any_sosog_is_a_valid_empty_screen(self):
        html_text = page('12')
        view.check_navigation(html_text, '12')
        self.assertEqual(view.options(html_text, P + 'ddlSosog'), [])

    def test_an_http_200_error_page_is_not_an_empty_screen(self):
        error = '<html><body><h1>세션이 만료되었습니다</h1></body></html>'
        with self.assertRaises(RuntimeError):
            view.check_navigation(error, '11')
        # Without the required form the sosog list is empty too, but never trusted.
        self.assertEqual(view.options(error, P + 'ddlSosog'), [])

    def test_missing_viewstate_college_list_or_term_drift_fails(self):
        with self.assertRaises(RuntimeError):
            view.check_navigation(page(viewstate=False), '11')
        with self.assertRaises(RuntimeError):
            view.check_navigation(page(colleges=False), '11')
        with self.assertRaises(RuntimeError):
            view.check_navigation(page(year='2025'), '11')
        with self.assertRaises(RuntimeError):
            view.check_navigation(page(term='1'), '11')

    def test_selection_drift_fails(self):
        with self.assertRaises(RuntimeError):
            view.check_navigation(page('12'), '11')
        with self.assertRaises(RuntimeError):
            view.check_navigation(page('11', hagbu='111'), '11', '112')
        with self.assertRaises(RuntimeError):
            view.check_navigation(page('11'), '11', '112')


if __name__ == '__main__':
    unittest.main()
