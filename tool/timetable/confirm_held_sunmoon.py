#!/usr/bin/env python3
"""Restore Sunmoon courses the importer dropped as closed (2026-11-23 decision).

Closed (폐강) courses printed in the official notice (dla nttSn=1324974, first
table) are kept like any other course. The importer recorded those rows in
'excludedClosedCourses' as the notice's cells [이수구분, 과목코드, 과목명, 분반,
시간, 교수]. Clock: the dataset's own table (clockEvidence, 60-minute slots,
period p starts at 08:30 + p hours; '목 4,5' = 11:30-13:30).

    python3 tool/timetable/confirm_held_sunmoon.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/sunmoon-unknown-2026-2.json'
DAYS = '월화수목금토일'
NOTICE = 'https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttInfo.do?bbsId=1256&mi=41117&nttSn=1324974'
NOTE = '공식 공지 첫 표의 폐강 과목. 2026-11-23 사용자 결정: 폐강 여부와 무관하게 공식 시간표 그대로 추가. 학점·강의실 원문 미표기'


def meetings(text):
    match = re.fullmatch(r'([월화수목금토일])\s*([\d,]+)', text.strip())
    if not match:
        raise ValueError(text)
    weekday = DAYS.index(match[1]) + 1
    return common.merge({'weekday': weekday, 'startMinute': 510 + p * 60, 'endMinute': 570 + p * 60,
                         'classroom': ''} for p in map(int, match[2].split(',')))


def main():
    dataset = common.load(PATH)
    closed = dataset.pop('excludedClosedCourses', [])
    template = dataset['courses'][0]
    for category, code, title, section, schedule, professor in closed:
        source_id = f'sunmoon/unknown/2026/2/{code}-{section}'
        if any(c['sourceId'] == source_id for c in dataset['courses']):
            continue
        dataset['courses'].append({
            'sourceId': source_id, 'universityId': 'sunmoon', 'campus': 'unknown',
            'campusName': template['campusName'], 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'courseName': title, 'section': section, 'professor': professor,
            'schedules': meetings(schedule), 'scheduleStatus': 'scheduled',
            'departments': ['교양학부'], 'departmentCredits': {},
            'departmentClassifications': {'교양학부': category},
            'departmentRemarks': {'교양학부': NOTE},
            'sourceSchedule': schedule, 'sourceClassroom': '', 'sourceUrl': NOTICE,
            'sourceCells': [category, code, title, section, schedule, professor],
            'period': template['period'], 'periodEvidence': template['periodEvidence'],
            'rowEvidence': '공식1324974 공지 첫표(폐강 과목)',
        })
    for course in dataset['courses']:
        if course.get('rowEvidence', '').endswith('; 첫표 폐강과목3개제외'):
            course['rowEvidence'] = course['rowEvidence'].replace('; 첫표 폐강과목3개제외', '')
    dataset['sourceRowCount'] = str(len(dataset['courses'])) if isinstance(dataset.get('sourceRowCount'), str) else len(dataset['courses'])
    common.save(PATH, dataset, '선문대 공식 공지의 폐강 과목 3개를 다시 넣음(2026-11-23 사용자 결정)')
    print(len(closed), 'restored')


if __name__ == '__main__':
    main()
