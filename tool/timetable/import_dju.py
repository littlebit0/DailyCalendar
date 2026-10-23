#!/usr/bin/env python3
"""Daejeon University (dju) 2026-2 from the official 강의시간표 공지 attachment.

Source: 학사공지 「2026학년도 2학기 본 수강신청 안내」
https://www.dju.ac.kr/dju/na/ntt/selectNttInfo.do?nttSn=553207&bbsId=1861&mi=1165
attachment 「붙임3_2026학년도 2학기 강의시간표 공지(2026. 8. 18.).zip」 with
  1. 교양교과목 강의시간표_08.18.xlsx
  2. 전공교과목 강의시간표_08.18.xlsx
  3. 일반선택 및 교직교과목 강의시간표_08.18.xlsx

  python3 tool/timetable/import_dju.py <dir with the three xlsx> <repository root>

Every row is kept with its original values. The school publishes weekday and
period numbers ("수(1,2)") but no period-to-clock table (학칙시행세칙 제23조 only
says a teaching unit is 50 or 75 minutes), so no clock time is invented: rows
with a printed weekday/period stay `unrecognized`, rows with an empty 시간표 cell
are `unscheduled`. Department labels and their 단과대학 are written exactly as
the official 전공/일반선택·교직 sheets print them.
"""
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NOTICE = 'https://www.dju.ac.kr/dju/na/ntt/selectNttInfo.do?nttSn=553207&bbsId=1861&mi=1165'
PERIOD = {'startDate': '2026-09-01', 'endDate': '2026-12-21'}
HOLD = '시각 보류: 공식 교시별 시각표 미공개(요일·교시만 공개)'
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
FILES = [
    ('1-general.xlsx', '교양교과목', None),
    ('2-major.xlsx', '전공교과목', 0),
    ('3-elective-teaching.xlsx', '일반선택 및 교직교과목', 0),
]


def rows(path):
    """First sheet of an xlsx as lists of strings (shared and inline strings)."""
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
    out = []
    sheet = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    for r in sheet.iter('{%s}row' % NS['m']):
        row = {}
        for c in r.findall('m:c', NS):
            col = 0
            for ch in re.match(r'[A-Z]+', c.get('r')).group(0):
                col = col * 26 + ord(ch) - 64
            v = c.find('m:v', NS)
            if c.get('t') == 's' and v is not None:
                row[col - 1] = shared[int(v.text)]
            elif c.get('t') == 'inlineStr':
                row[col - 1] = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['m']))
            elif v is not None:
                row[col - 1] = v.text
        if row:
            out.append([(row.get(i) or '').strip() for i in range(max(row) + 1)])
    return out


def header(two):
    """Join the two header rows: '강의시수' spans 이론/실습, entrance-year areas span 3 columns."""
    top, sub = two
    names, parent = [], ''
    for i, t in enumerate(top):
        t = re.sub(r'\s+', '', t)
        s = sub[i] if i < len(sub) else ''
        parent = t or parent
        names.append(f'{parent} {s}' if s else t)
    return names


def build(src, root):
    courses, labels = [], {}
    for name, sheet, college_col in FILES:
        data = rows(Path(src) / name)
        head = header(data[:2])
        col = {h: i for i, h in enumerate(head)}
        for r in data[2:]:
            r = r + [''] * (len(head) - len(r))
            get = lambda h: r[col[h]]
            code, sec, time = get('학수번호'), get('분반'), get('시간표')
            cls = get('이수구분')
            dept = get('학부·학과(전공)') if college_col is not None else ''
            if dept:
                labels.setdefault(dept, (r[college_col], name, code, sec))
            text = ' / '.join(f'{h} {v}' for h, v in zip(head, r) if v)
            status = 'unrecognized' if time else 'unscheduled'
            remarks = f'2026-2 공식 강의시간표 공지(2026. 8. 18.) {sheet} 원문: {text}'
            course = {
                'sourceId': f'dju/main/2026-2/{code}-{sec}',
                'campus': 'main', 'academicYear': 2026, 'semester': '2',
                'courseCode': code, 'section': sec, 'courseName': get('과목명'),
                'professor': get('담당교수'), 'classification': cls,
                'credits': float(get('학점')),
                'departments': [dept] if dept else [],
                'departmentCredits': {},
                'departmentClassifications': {dept: cls} if dept else {},
                'sourceSchedule': time, 'sourceClassroom': get('강의실'),
                'remarks': remarks + (f' | {HOLD}' if time else ''),
                'period': PERIOD, 'scheduleStatus': status, 'schedules': [],
            }
            if time:
                course['holdReasons'] = [HOLD.removeprefix('시각 보류: ')]
            courses.append(course)
    ids = [c['sourceId'] for c in courses]
    assert len(ids) == len(set(ids)), 'duplicate code+section'
    counts = {}
    for c in courses:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    dataset = {
        'schemaVersion': 1, 'universityId': 'dju', 'campus': 'main', 'campusName': '본교',
        'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-08-18',
        'sourceUrl': NOTICE,
        'sourceNotice': '2026학년도 2학기 강의시간표 공지(2026. 8. 18.) 첨부 xlsx 3종. '
                        '학교 안내: 실시간 변경은 통합정보시스템(로그인)에서만 확인 가능.',
        'retrievedDate': '2026-10-23', 'sourceRowCount': len(courses),
        'courseScheduleStatusCounts': counts, 'completionClaim': False,
        'courses': courses,
    }
    out = Path(root) / 'assets/timetable/dju-main-2026-2.json'
    out.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    spec = [
        {'label': d, 'campus': '*', 'college': college, 'url': NOTICE,
         'file': f'work/issue-598-dju-timetable/src/{f}',
         'evidence': f'2026-2 공식 강의시간표 공지(2026. 8. 18.) {f} 행 {code}-{sec}: '
                     f'「단과대학」 "{college}", 「학부·학과(전공)」 "{d}"'}
        for d, (college, f, code, sec) in labels.items()
    ]
    print(json.dumps({'courses': len(courses), 'status': counts, 'labels': len(spec)}, ensure_ascii=False))
    return spec


if __name__ == '__main__':
    spec = build(sys.argv[1], sys.argv[2])
    if len(sys.argv) > 3:
        Path(sys.argv[3]).write_text(json.dumps(spec, ensure_ascii=False, indent=1), encoding='utf-8')
