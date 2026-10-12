#!/usr/bin/env python3
"""Import Sejong's complete official undergraduate XLSX, preserving department
scoped course numbers and real clock times (not inferred period numbers).

Requires the already available openpyxl runtime. No student login is involved.
"""
import argparse
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
HEADER = ['순번', '개설대학', '개설학과코드', '개설학과전공', '학수번호', '분반',
          '교과목명', '이수구분', '학년\n(학기)', '학점', '이론', '실습', '수업\n유형',
          '학점교류\n수강가능', '요일 및 강의시간', '강의실', '메인\n교수명', '주관학과',
          '수강대상및유의사항', '강좌유형', '사이버강좌', '강의언어', '외국인\n전용', '내국인\n전용']


def text(value):
    return '' if value is None else str(value).strip()


def meetings(schedule, classroom):
    if not schedule:
        return []
    groups = schedule.split(',')
    parsed = []
    for group in groups:
        m = re.fullmatch(r'\s*([월화수목금토일](?:\s*[월화수목금토일])*)\s+(\d{2}):(\d{2})~(\d{2}):(\d{2})\s*', group)
        if m is None:
            raise ValueError('Unrecognized Sejong clock schedule')
        sh, sm, eh, em = map(int, m.groups()[1:])
        start, end = sh*60+sm, eh*60+em
        if sm > 59 or em > 59 or not 0 <= start < end <= 1440:
            raise ValueError('Invalid Sejong clock schedule')
        days = [DAYS.index(d)+1 for d in m[1] if d in DAYS]
        if len(set(days)) != len(days):
            raise ValueError('Repeated Sejong weekday')
        parsed.append((days, start, end))
    rooms = [s.strip() for s in classroom.split(',')]
    count = sum(len(days) for days, _, _ in parsed)
    if len(rooms) not in [1, count, len(parsed)]:
        raise ValueError('Ambiguous Sejong classroom mapping')
    result = []
    for index, (days, start, end) in enumerate(parsed):
        for day in days:
            room = rooms[0] if len(rooms) == 1 else rooms[len(result)] if len(rooms) == count else rooms[index]
            result.append({'weekday': day, 'startMinute': start, 'endMinute': end, 'classroom': room})
    return result


def parse_rows(rows, year, semester, expected_rows):
    if not rows or list(rows[0]) != HEADER or len(rows)-1 != expected_rows:
        raise ValueError('Wrong Sejong scope or incomplete published workbook')
    courses = []
    ids = set()
    for index, row in enumerate(rows[1:], 1):
        if len(row) != 24 or row[0] != index:
            raise ValueError('Incomplete Sejong row sequence')
        values = [text(v) for v in row]
        department_code, department, code, section = values[2:6]
        if not re.fullmatch(r'\d+', department_code) or not re.fullmatch(r'[A-Z0-9]{6}', code) or not re.fullmatch(r'\d{3}', section) or not department or not values[6] or not values[7]:
            raise ValueError('Invalid Sejong course identity')
        # The same code/section denotes DIFFERENT lectures in distinct opening
        # departments (e.g. 011839-001). Never collapse by code/section alone.
        source_id = f'sejong/main/{year}/{semester}/{department_code}/{code}/{section}'
        if source_id in ids:
            raise ValueError('Duplicate Sejong department course')
        ids.add(source_id)
        credits = float(values[9])
        if not 0 <= credits <= 30:
            raise ValueError('Invalid Sejong credits')
        slots = meetings(values[14], values[15])
        fields = [(18, '수강대상 및 유의사항'), (8, '학년(학기)'),
                  (12, '수업 유형'), (13, '학점교류 수강가능'),
                  (17, '주관학과'), (19, '강좌유형'), (20, '사이버강좌'),
                  (21, '강의언어'), (22, '외국인 전용'), (23, '내국인 전용')]
        remark = '\n'.join(f'{label}: {values[column]}' for column, label in fields if values[column])
        courses.append({'sourceId': source_id, 'universityId': 'sejong',
                        'campus': 'main', 'academicYear': year, 'semester': semester,
                        'courseCode': code, 'section': section, 'courseName': values[6],
                        'professor': values[16], 'credits': credits,
                        'sourceSchedule': values[14], 'sourceClassroom': values[15],
                        'scheduleStatus': 'scheduled' if slots else 'unscheduled',
                        'schedules': slots, 'departments': [department],
                        'departmentCredits': {department: credits},
                        'departmentClassifications': {department: values[7]},
                        'departmentRemarks': {department: remark}})
    return courses


if __name__ == '__main__':
    import openpyxl
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--semester', choices=['1', '2', '여름', '겨울'], required=True)
    parser.add_argument('--expected-rows', type=int, required=True)
    parser.add_argument('--published-date', required=True)
    parser.add_argument('--source-url', required=True)
    args = parser.parse_args()
    workbook = openpyxl.load_workbook(args.input, read_only=True, data_only=True)
    if workbook.sheetnames != ['개설강좌']:
        raise ValueError('Unexpected Sejong workbook')
    courses = parse_rows(list(workbook.active.values), args.year, args.semester, args.expected_rows)
    args.output.write_text(json.dumps({'schemaVersion': 1, 'universityId': 'sejong',
                                      'campus': 'main', 'campusName': '서울',
                                      'academicYear': args.year, 'semester': args.semester,
                                      'publishedDate': args.published_date, 'sourceUrl': args.source_url,
                                      'courses': courses}, ensure_ascii=False, indent=2)+'\n')
    print('Sejong courses:', len(courses), 'scheduled:', sum(bool(c['schedules']) for c in courses))
