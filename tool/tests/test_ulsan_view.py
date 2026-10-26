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


def area_page(search_type='4', area='A1', grade='1', areas=(('A1', '교양1'), ('A2', '교양2')), viewstate=True, term='2'):
    parts = []
    if viewstate:
        parts.append('<input type="hidden" name="__VIEWSTATE" value="x" />')
    parts.append('<input type="text" name="' + P + 'imedYy" value="2026" />')
    parts.append(select('ddlHaggi', [('1', '1학기'), ('2', '2학기')], term))
    parts.append(select('ddlSearchType', [('1', '전공별'), ('4', '영역별')], search_type))
    if areas:
        parts.append(select('ddlYeong', list(areas), area))
    parts.append(select('ddlHagnyeon', [(str(i), str(i)) for i in range(1, 6)], grade))
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

    def test_area_view_accepts_the_real_switch_and_search_responses(self):
        view.check_area_view(area_page())
        view.check_area_view(area_page(area='A2', grade='3'), 'A2', '3')

    def test_an_error_page_never_reads_as_an_empty_area_list(self):
        error = '<html><body>오류가 발생했습니다</body></html>'
        with self.assertRaises(RuntimeError):
            view.check_area_view(error)
        self.assertEqual(view.options(error, P + 'ddlYeong'), [])
        for bad in (area_page(viewstate=False), area_page(areas=()), area_page(search_type='1'),
                    area_page(term='1')):
            with self.assertRaises(RuntimeError):
                view.check_area_view(bad)

    def test_area_or_grade_selection_drift_fails(self):
        with self.assertRaises(RuntimeError):
            view.check_area_view(area_page(area='A1'), 'A2', '1')
        with self.assertRaises(RuntimeError):
            view.check_area_view(area_page(grade='2'), 'A1', '1')


if __name__ == '__main__':
    unittest.main()
