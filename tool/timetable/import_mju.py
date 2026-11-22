#!/usr/bin/env python3
"""Myongji University (mju) 2026-2 from the official 개설강좌현황표 xlsx.

Source: 입학처 게시글 「2026-2학기 개설강좌현황표_20260812(학생 참고용).xlsx」
https://iphak.mju.ac.kr/pages/?p=1&b=B_1_1&bn=30276&m=read&nPage=1&cate=%EC%8B%9C%EA%B0%84%EC%A0%9C
file https://iphak.mju.ac.kr/_common/new_download_file.php?menu=boardfile&file_no=10702

  python3 tool/timetable/import_mju.py <xlsx> <repository root>

Writes assets/timetable/mju-{humanities,natural}-2026-2.json and
assets/timetable/organizations/mju.json as compact JSON.

Every row is one course (강좌번호 is unique; 분반 is not published). 수업시간 cells
are printed clock times ("1100 - 1150"), so they become weekly meetings as
printed. No 이수구분 is published: classification stays "" and 강좌유형 is kept
in the original row text in remarks. Rows are held as `unrecognized` (no
meetings) when 비고 says the course does not meet every week of the semester
(집중이수제, D-학기제, n주, 상·하반기 …) or 자율수강제, or when a printed slot
starts before 06:00 (online placeholder clocks such as "0000 - 0300"). Rows
without any 요일 are `unscheduled`.

Semester period: 명지대학교 2026 학사일정 (https://www.mju.ac.kr/mjukr/262/subview.do,
yearSchdul.do year=2026): 09.01 「학기 개시일, 2학기 개강」 through 12.15~12.18
「공휴일로 인한 수업보강(기말고사) 기간」 (기말고사 12.08~12.14).
"""
import hashlib
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NOTICE = ('https://iphak.mju.ac.kr/pages/?p=1&b=B_1_1&bn=30276&m=read&nPage=1'
          '&cate=%EC%8B%9C%EA%B0%84%EC%A0%9C')
FILE_URL = 'https://iphak.mju.ac.kr/_common/new_download_file.php?menu=boardfile&file_no=10702'
FILE_NAME = '2026-2학기 개설강좌현황표_20260812(학생 참고용).xlsx'
PERIOD = {'startDate': '2026-09-01', 'endDate': '2026-12-18'}
CAMPUS = {'인문': ('humanities', '인문캠퍼스'), '자연': ('natural', '자연캠퍼스')}
WEEKDAY = {'월요일': 1, '화요일': 2, '수요일': 3, '목요일': 4, '금요일': 5, '토요일': 6, '일요일': 7}
NOT_WEEKLY = re.compile(r'D-학기제|D-프로젝트|집중|\d+\s*주|상반기|하반기|자율수강제')
HOLD_NOT_WEEKLY = '시각 보류: 비고가 학기 전체 매주 수업이 아님을 표시(집중이수·D-학기제·주차 한정·자율수강제 등)'
HOLD_PLACEHOLDER = '시각 보류: 06:00 이전 시작 시각 표기(원격강좌 자리표시 시각으로 보임)'
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
COLLEGE_ROW = '대학'  # 단과대 "대학" rows print the college itself in 학과명.
PROGRAM_GROUPS = {'융합전공'}  # 단과대 열에 전공제도 이름이 인쇄된 묶음


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


def slots(r):
    """(weekday text, time text, room, parsed minutes or None) for each printed slot."""
    out = []
    for k in '123':
        day, time, room = r[f'요일{k}'], r[f'수업시간{k}'], r[f'강의실{k}']
        if not day and time in ('', '-'):
            continue
        m = re.fullmatch(r'(\d\d)(\d\d) - (\d\d)(\d\d)', time)
        if day not in WEEKDAY or not m:
            raise ValueError(f"{r['강좌번호']}: unexpected slot {day!r} {time!r}")
        a, b, c, d = map(int, m.groups())
        start, end = a * 60 + b, c * 60 + d
        if b > 59 or d > 59 or not 0 <= start < end <= 1440:
            raise ValueError(f"{r['강좌번호']}: invalid clock {time!r}")
        out.append((day, time, room, start, end))
    return out


def build(src, root):
    data = rows(src)
    sha = hashlib.sha256(Path(src).read_bytes()).hexdigest()
    head = [re.sub(r'\s+', '', h) for h in data[0]]
    table = [dict(zip(head, r + [''] * (len(head) - len(r)))) for r in data[1:]]
    by_campus = {cid: [] for cid, _ in CAMPUS.values()}
    labels = {}
    for r in table:
        if (r['년도'], r['학기']) != ('2026', '2'):
            raise ValueError(f"{r['강좌번호']}: not 2026-2")
        campus, _ = CAMPUS[r['캠퍼스']]
        code, dept, college = r['강좌번호'], r['학과명'], r['단과대']
        if not (code and dept and college and r['교과목명']):
            raise ValueError(f'missing key cell: {r}')
        labels.setdefault(dept, (campus, college, code))
        if labels[dept][:2] != (campus, college):
            raise ValueError(f'{dept}: printed under two campuses/colleges')
        found = slots(r)
        remark = r['비고']
        hold = None
        if found and NOT_WEEKLY.search(remark):
            hold = HOLD_NOT_WEEKLY
        elif any(s[3] < 360 for s in found):
            hold = HOLD_PLACEHOLDER
        status = 'unscheduled' if not found else 'unrecognized' if hold else 'scheduled'
        text = ' / '.join(f'{h} {v}' for h, v in r.items() if v and v != '-')
        credits = float(r['학점'])
        course = {
            'sourceId': f'mju/{campus}/2026/2/{code}',
            'campus': campus, 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': '', 'courseName': r['교과목명'],
            'professor': r['교강사명'], 'classification': '', 'credits': credits,
            'departments': [dept], 'departmentCredits': {dept: credits},
            'departmentClassifications': {},
            'sourceSchedule': ', '.join(f'{s[0]} {s[1]}' for s in found),
            'sourceClassroom': ', '.join(s[2] for s in found if s[2]),
            'remarks': f'2026-2학기 개설강좌현황표(2026. 8. 12.) 원문: {text}'
                       + (f' | {hold}' if hold else ''),
            'period': PERIOD, 'scheduleStatus': status,
            'schedules': [] if status != 'scheduled' else [
                {'weekday': WEEKDAY[s[0]], 'startMinute': s[3], 'endMinute': s[4], 'classroom': s[2]}
                for s in found
            ],
        }
        if hold:
            course['holdReasons'] = [hold.removeprefix('시각 보류: ')]
        by_campus[campus].append(course)
    ids = [c['courseCode'] for cs in by_campus.values() for c in cs]
    assert len(ids) == len(set(ids)) == len(table), 'duplicate 강좌번호'
    root = Path(root)
    summary = {}
    for code_name, (campus, name) in CAMPUS.items():
        courses = by_campus[campus]
        counts = {}
        for c in courses:
            counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
        dataset = {
            'schemaVersion': 2, 'universityId': 'mju', 'campus': campus, 'campusName': name,
            'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-08-12',
            'sourceUrl': NOTICE,
            'sourceNotice': f'입학처 게시 「{FILE_NAME}」({FILE_URL}) 캠퍼스 열 "{code_name}" 행. '
                            '학생 참고용 자료이며 분반·이수구분은 공개되지 않았습니다.',
            'sourceHashes': {FILE_NAME: sha}, 'sourceRowCount': len(courses), 'courseScheduleStatusCounts': counts,
            'researchOnly': False, 'productionIntegrationEnabled': True,
            'completionClaim': False, 'wholeOperatingVerified': False,
            'courses': courses,
        }
        write(root / f'assets/timetable/mju-{campus}-2026-2.json', dataset)
        summary[campus] = counts
    mappings = []
    for dept, (campus, college, code) in labels.items():
        evidence = f'{FILE_NAME} 단과대 열 "{college}", 학과명 열 "{dept}" (강좌번호 {code})'
        base = {'sourceLabel': dept, 'sourceUrl': NOTICE, 'evidence': evidence,
                'sourceFile': FILE_URL, 'campus': campus, 'collegeKnown': True}
        if college == COLLEGE_ROW:
            mappings.append({'college': dept, 'department': None, **base,
                             'isOfferingUnit': True, 'affiliationStatus': 'verified'})
        elif college in PROGRAM_GROUPS:
            mappings.append({'group': college, 'department': dept, **base,
                             'isOfferingUnit': False, 'affiliationStatus': 'officialProgramSystem'})
        else:
            mappings.append({'college': college, 'department': dept, **base,
                             'isOfferingUnit': False, 'affiliationStatus': 'verified'})
    write(root / 'assets/timetable/organizations/mju.json',
          {'schemaVersion': 1, 'university': 'mju', 'mappings': mappings, 'courseOwners': []})
    result = {'rows': len(table), 'status': summary, 'mappings': len(mappings)}
    print(json.dumps(result, ensure_ascii=False))
    return result


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2])
