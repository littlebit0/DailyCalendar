import importlib.util
from html import escape
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


spec = importlib.util.spec_from_file_location(
    'dku', Path(__file__).resolve().parents[1] / 'timetable/import_dankook.py')
dku = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dku)


def course_row(code='123456', *, schedule='월1~3(공학101)', remarks='신입생 전용\n둘째 줄',
               department='공과대학\n컴퓨터학과', professor='공식 교수', credits='3(0)'):
    return ['1', '전공선택', code, '공식 강의명', '1', '', credits, professor,
            schedule, '', remarks, '대면수업', department]


def table(rows, *, primary=False, cheonan=False, declared=None, year=2026):
    headers = list(dku.HEADERS)
    if cheonan:
        headers[5] = '원어'
    if primary:
        headers.append('주수강조직')
    html = f'<p><em class="fc_orange">{len(rows) if declared is None else declared}건</em></p>'
    html += '<table id="mjLctTmtblDscTbl"><thead><tr>'
    html += ''.join(f'<th>{escape(header)}</th>' for header in headers)
    html += '</tr></thead><tbody>'
    for row in rows:
        html += '<tr>'
        for index, value in enumerate(row):
            html += '<td>' + escape(value).replace('\n', '<br>')
            if index == 3:
                html += '<a href="#">국문</a><a href="#">ENG</a>'
                html += f'<input name="yy" value="{year}"><input name="semCd" value="2">'
                html += f'<input name="subjId" value="{row[2]}"><input name="dvclsNb" value="{row[4]}">'
                html += '<input name="pfltId" value="not-imported">'
            html += '</td>'
        html += '</tr>'
    return html + '</tbody></table>'


class DankookImportTests(unittest.TestCase):
    def extract(self, major, general=(), basic=()):
        with TemporaryDirectory() as directory:
            for group, rows in [('major', major), ('general', general), ('basic', basic)]:
                dku.source_path(directory, 'jukjeon', group).write_text(
                    table(rows, primary=group == 'basic'))
            return dku.extract(directory, 'jukjeon', 2026, '2', '2026-09-26')

    def test_day_and_night_periods_preserve_the_official_minutes(self):
        self.assertEqual(dku.meeting_times('월1~3(공학101)\n수19~21'), [
            {'weekday': 1, 'startMinute': 540, 'endMinute': 630, 'classroom': '공학101'},
            {'weekday': 3, 'startMinute': 1080, 'endMinute': 1240, 'classroom': ''},
        ])
        self.assertEqual(dku.meeting_times('토18~20(A)')[0]['endMinute'], 1185)
        self.assertEqual(dku.meeting_times('금24')[0]['endMinute'], 1405)

    def test_disconnected_periods_and_distinct_rooms_are_never_filled_in(self):
        meetings = dku.meeting_times('월1,3(A) 월4(B)')
        self.assertEqual(len(meetings), 3)
        self.assertEqual([(m['startMinute'], m['endMinute']) for m in meetings],
                         [(540, 570), (600, 630), (630, 660)])
        for invalid in ['월0', '화25', '수3~1', '목1,1', '금1~3(미정)추가', '시간미정']:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                dku.meeting_times(invalid)

    def test_official_headers_count_term_and_section_are_checked(self):
        row = course_row()
        self.assertEqual(dku.parse_table(table([row]), 2026, '2'), [row])
        self.assertEqual(dku.parse_table(table([row], cheonan=True), 2026, '2'), [row])
        for html in [table([row], declared=2), table([row], year=2025),
                     table([row]).replace('교강사', '알수없는열'),
                     table([row]).replace('name="dvclsNb" value="1"', 'name="dvclsNb" value="2"')]:
            with self.subTest(html=html), self.assertRaises(ValueError):
                dku.parse_table(html, 2026, '2')

    def test_cross_listed_rows_keep_each_department_and_enrollment_remarks(self):
        first = course_row()
        second = course_row(department='융합대학\n융합학과', remarks='다전공 신청 가능')
        second[1] = '전공필수'
        foundational = [*first, '공과대학 컴퓨터학과']
        result = self.extract([first, second], [first], [foundational])
        self.assertEqual(result['sourceRowCount'], 4)
        self.assertEqual(len(result['courses']), 1)
        course = result['courses'][0]
        self.assertEqual(course['sourceId'], 'dku/jukjeon/2026/2/123456/1')
        self.assertEqual(course['sourceGroups'], ['major', 'general', 'basic'])
        self.assertEqual(course['departmentClassifications'], {
            '공과대학 / 컴퓨터학과': '전공선택', '융합대학 / 융합학과': '전공필수'})
        self.assertIn('신입생 전용\n둘째 줄', course['departmentRemarks']['공과대학 / 컴퓨터학과'])
        self.assertIn('주수강조직: 공과대학 컴퓨터학과', course['departmentRemarks']['공과대학 / 컴퓨터학과'])
        self.assertEqual(course['courseName'], '공식 강의명')
        self.assertNotIn('pfltId', str(course))
        self.assertNotIn('defaultMode', course)

    def test_unscheduled_and_unrecognized_courses_remain_searchable_without_guessed_times(self):
        result = self.extract([
            course_row('123456', schedule=''),
            course_row('123457', schedule='별도 공지 예정'),
            course_row('123458', schedule='목1~3', credits='.5(0)'),
        ])
        self.assertEqual(result['courseScheduleStatusCounts'], {
            'unscheduled': 1, 'unrecognized': 1, 'scheduled': 1})
        self.assertEqual(result['courses'][0]['schedules'], [])
        self.assertEqual(result['courses'][1]['sourceSchedule'], '별도 공지 예정')
        self.assertEqual(result['courses'][1]['schedules'], [])
        self.assertEqual(result['courses'][2]['credits'], .5)
        self.assertEqual(result['courses'][2]['schedules'][0]['classroom'], '')

    def test_contradictory_section_metadata_fails_instead_of_silent_merge(self):
        for other in [course_row(professor='다른 교수'),
                      course_row(schedule='목1~3'), course_row(credits='2(0)')]:
            with self.subTest(other=other), self.assertRaisesRegex(ValueError, 'Conflicting official section'):
                self.extract([course_row(), other])


if __name__ == '__main__':
    unittest.main()
