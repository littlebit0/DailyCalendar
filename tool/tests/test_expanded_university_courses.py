import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tool' / 'timetable' / f'import_{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ExpandedUniversityCoursesTest(unittest.TestCase):
    def test_inha_half_hour_rooms_and_overnight_split(self):
        inha = load('inha')
        days = '월화수목금토'
        options = [[f'D{day}T{"123456789ABCDEFGHIJKLMNO"[slot-1]}',
                    f'{days[day-1]}{slot}({(540+(slot-1)*30)//60:02}:{(540+(slot-1)*30)%60:02})']
                   for day in range(1,7) for slot in range(1,25)]
        parsed = inha.meetings('월1,2,3(강의실 A) /수4,5,6(강의실 B)',
                               'D1T1T2T3D3T4T5T6',options)
        self.assertEqual([(r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in parsed],
                         [(1,540,630,'강의실 A'),(3,630,720,'강의실 B')])
        self.assertEqual(inha.meetings('셀0(웹강의)','D0T0',options),[])
        night = inha.meetings('목21,22,23,24,25,26,27,28,29,30,31,32(항공-216)',
                             'D4T21T22T23T24T25T26T27T28T29T30T31T32',options)
        self.assertEqual([(r['weekday'],r['startMinute'],r['endMinute']) for r in night],
                         [(4,1140,1440),(5,0,60)])
        with self.assertRaises(ValueError):
            inha.meetings('월33(강의실)','D1T33',options)
        with self.assertRaises(ValueError):
            inha.meetings('월1,2(강의실)','D1T1T3',options)
        clipped_text = '월9,10,11,12,13,14,15,16,17,18,19,20,목9,10,11,12,13,14,15,16,17,18,19,20(4-422)'
        clipped_code = 'D1T9T10T11T12T13T14T15T16T17T18T19T20D4T9T10T11T12'
        self.assertEqual(len(clipped_code),50)
        self.assertEqual(len(inha.meetings(clipped_text,clipped_code,options)),2)
        with self.assertRaises(ValueError):
            inha.meetings(clipped_text,clipped_code.replace('D1','D2',1),options)

    def test_cau_campus_clock_and_flexible_course_identity(self):
        cau = load('cau')
        seoul, status = cau.meetings('월1,2 / 강의실', '1')
        davinci, _ = cau.meetings('월1,2 / 강의실', '2')
        self.assertEqual(status, 'scheduled')
        self.assertEqual((seoul[0]['startMinute'], seoul[0]['endMinute']), (540, 650))
        self.assertEqual((davinci[0]['startMinute'], davinci[0]['endMinute']), (570, 680))
        explicit, _ = cau.meetings('화10:30~11:45, 목10:30~11:45 / A / B', '1')
        self.assertEqual(len(explicit), 2)
        self.assertEqual(explicit[0]['classroom'], 'A / B')
        row = {'shtm':'2','corscd':'학사','campcd':'1','sbjtno':'51097','clssno':'01',
               'clssnm':'CAU세미나(2)','sust':'3A110','sustnm':'국어국문학과','pnt':'.5-.5',
               'ltbdrm':'월1 / 강의실','flx':'Term3','profnm':'교수','pobtnm':'전공',
               'remk':'소속 학생만 수강'}
        other = dict(row, sust='3A120', sustnm='영어영문학과', profnm='다른 교수')
        courses = cau.parse_rows([row, row, other], 2026, '2')
        self.assertEqual(len(courses), 2)
        self.assertEqual(courses[0]['credits'], 0.5)
        self.assertEqual(courses[0]['period']['endDate'], '2026-10-26')
        self.assertIn('소속 학생만 수강', courses[0]['departmentRemarks']['국어국문학과'])
        self.assertEqual(len(cau.parse_rows([row, dict(other, clsefg='폐강')], 2026, '2')), 1)
        with self.assertRaises(ValueError):
            cau.parse_rows([dict(row, flx='Term5')], 2026, '2')

    def test_snu_official_rows_keep_second_meeting_and_restrictions(self):
        snu = load('snu')
        body = (ROOT / 'test/fixtures/academic/snu-courses-2026-2-page1.html').read_text()
        total, courses = snu.parse_page(body, 2026, 2)
        self.assertEqual(total, 3744)
        self.assertEqual(len(courses), 10)
        self.assertEqual(courses[0]['courseCode'], 'C10.101')
        self.assertEqual(courses[0]['section'], '001')
        self.assertEqual(len(courses[0]['schedules']), 2)
        self.assertEqual(courses[0]['schedules'][0]['endMinute'], 735)
        self.assertEqual(courses[0]['schedules'][1]['weekday'], 3)
        with self.assertRaises(ValueError):
            snu.parse_page(body, 2025, 2)
        with self.assertRaises(ValueError):
            snu.parse_page(body.replace('월(11:00~12:15)', '월(11:00~10:15)'), 2026, 2)

    def test_ajou_official_periods_and_unpublished_room(self):
        ajou = load('ajou')
        rows, status = ajou.meetings('월G(율256) 목H(율256)')
        self.assertEqual(status, 'scheduled')
        self.assertEqual(rows[0]['startMinute'], 1080)
        self.assertEqual(rows[1]['endMinute'], 1245)
        rows, status = ajou.meetings('수8.5(산825) 수9.5(산825) 수10.5')
        self.assertEqual(status, 'scheduled')
        self.assertEqual(rows[0]['startMinute'], 990)
        self.assertEqual(rows[-1]['classroom'], '')
        self.assertEqual(ajou.meetings('화16:30~18:00')[0][0]['endMinute'], 1080)
        self.assertEqual(ajou.meetings('금I(율256)'), ([], 'unparsed'))
        self.assertEqual(ajou.meetings(''), ([], 'unscheduled'))
        with self.assertRaises(ValueError):
            ajou.meetings('화16:30~16:10')

    def test_ajou_teacher_groups_and_missing_credits_are_preserved(self):
        ajou = load('ajou')
        row = {'yy': '2026', 'shtmCd': 'U0002003', 'sbjtCd': 'HUM107', 'clssNo': '1',
               'sbjtKorNm': '강의', 'sustCdNm': '학과', 'mjCdNm': '', 'pnt': None,
               'openLtNo': '202614720', 'maLecturerEmplNm': '교수1', 'ltTmNm': '월B(연암612)',
               'ltRoomNm': '연암612', 'submattFgNm': '전공과목'}
        second = {**row, 'maLecturerEmplNm': '교수2', 'ltTmNm': '월B(다108)', 'ltRoomNm': '다108'}
        courses = ajou.parse_rows([row, second], 2026, '2')
        self.assertEqual(len(courses), 2)
        self.assertNotEqual(courses[0]['sourceId'], courses[1]['sourceId'])
        self.assertIsNone(courses[0]['credits'])
        self.assertEqual(courses[0]['departmentCredits'], {})
        self.assertEqual(courses[1]['schedules'][0]['classroom'], '다108')


if __name__ == '__main__':
    unittest.main()
