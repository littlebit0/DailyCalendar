import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('import_mju', ROOT / 'tool/timetable/import_mju.py')
mju = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mju)


def row(**cells):
    base = {f'{k}{i}': '' for k in ('요일', '수업시간', '강의실') for i in '123'}
    base.update({'수업시간2': '-', '수업시간3': '-', '강좌번호': '0001'})
    base.update(cells)
    return base


class ImportMjuSlotTests(unittest.TestCase):
    def test_printed_clock_becomes_minutes(self):
        self.assertEqual(mju.slots(row(요일1='수요일', 수업시간1='1100 - 1150', 강의실1='Y23212')),
                         [('수요일', '1100 - 1150', 'Y23212', 660, 710)])

    def test_empty_slots_are_skipped_and_bad_ones_rejected(self):
        self.assertEqual(mju.slots(row(수업시간1='-')), [])
        with self.assertRaises(ValueError):
            mju.slots(row(요일1='수요일', 수업시간1='11:00'))

    def test_non_weekly_remarks(self):
        for text in ('3학년 2학기 D-학기제 수업(집중수업/10주)', '집중이수제(상반기8주)-신입생전용',
                     '하반기 집중이수', 'MJU자율수강제강좌(LMS)'):
            self.assertTrue(mju.NOT_WEEKLY.search(text), text)
        for text in ('경영, 국통, 경정 전공 인정', '26학번 전용강좌', '5801 강좌번호로 신청 필수'):
            self.assertFalse(mju.NOT_WEEKLY.search(text), text)


class ImportMjuAssetTests(unittest.TestCase):
    def test_generated_assets_cover_every_source_row(self):
        courses, counts = [], {}
        for campus in ('humanities', 'natural'):
            data = json.loads((ROOT / f'assets/timetable/mju-{campus}-2026-2.json').read_text(encoding='utf-8'))
            self.assertEqual(data['sourceRowCount'], len(data['courses']))
            self.assertEqual(sum(data['courseScheduleStatusCounts'].values()), len(data['courses']))
            for c in data['courses']:
                counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
                self.assertEqual(bool(c['schedules']), c['scheduleStatus'] == 'scheduled', c['sourceId'])
            courses += data['courses']
        self.assertEqual(len(courses), 1523)
        self.assertEqual(len({c['courseCode'] for c in courses}), 1523)
        self.assertEqual(sum(counts.values()), 1523)
        labels = {d for c in courses for d in c['departments']}
        org = json.loads((ROOT / 'assets/timetable/organizations/mju.json').read_text(encoding='utf-8'))
        self.assertEqual({m['sourceLabel'] for m in org['mappings']}, labels)


if __name__ == '__main__':
    unittest.main()
