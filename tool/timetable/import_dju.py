#!/usr/bin/env python3
"""Daejeon University (dju) 2026-2 from the official 강의시간표 공지 attachment.

Source: 학사공지 「2026학년도 2학기 본 수강신청 안내」
https://www.dju.ac.kr/dju/na/ntt/selectNttInfo.do?nttSn=553207&bbsId=1861&mi=1165
attachment 「붙임3_2026학년도 2학기 강의시간표 공지(2026. 8. 18.).zip」 with
  1. 교양교과목 강의시간표_08.18.xlsx
  2. 전공교과목 강의시간표_08.18.xlsx
  3. 일반선택 및 교직교과목 강의시간표_08.18.xlsx

  python3 tool/timetable/import_dju.py <dir with the three xlsx> <repository root>

Every row is kept with its original values. The sheets print weekday and
period numbers ("수(1,2)"). Period clock times come from the school's own
교시표 (see PERIOD_EVIDENCE): 1교시 09:00~09:50 ... 9교시 17:00~17:50, i.e. a
60-minute slot (50분 수업 + 10분) starting 09:00, matching 학칙시행세칙 제23조
(운영 단위 50분). Periods outside the 1~9 table (0, 10~14) continue the same
slot length. Consecutive periods on one weekday form one block; rows with an
empty 시간표 cell are `unscheduled`. Department labels and their 단과대학 are
written exactly as the official 전공/일반선택·교직 sheets print them.
"""
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NOTICE = 'https://www.dju.ac.kr/dju/na/ntt/selectNttInfo.do?nttSn=553207&bbsId=1861&mi=1165'
PERIOD = {'startDate': '2026-09-01', 'endDate': '2026-12-21'}
PERIOD_EVIDENCE = (
    '교시 시각 근거(2026-11-23 조회): 대전대학교 총장 명의 「2025학년도 하계 계절수업 학점교류 수학 안내」 '
    '7. 수업시간 "1교시 09:00~09:50, 2교시 10:00~10:50 … 9교시 17:00~17:50" '
    '(https://plus.cnu.ac.kr/html/kr/25file/2025_0523_dnu.pdf, 2023 동계판 '
    'https://plus.cnu.ac.kr/html/kr/23file/2023_1130_djnu.pdf 동일); 정규학기 기초·교양학부 '
    '「2025-1 글쓰기 클리닉 시간표」 "1교시 09:00~09:30·09:30~10:00 … 9교시 17:00~17:30·17:30~18:00" '
    '(https://www.dju.ac.kr/communicationclinic/cm/cntnts/cntntsView.do?mi=3331&cntntsId=2057); '
    '학칙시행세칙 제23조 "강의시간의 운영 단위는 50분 또는 75분". 교시 슬롯 60분(50분+10분), '
    '표에 없는 0·10~14교시는 같은 슬롯 길이로 이어 계산'
)
WEEKDAYS = '월화수목금토일'


def meetings(text, room):
    """'월(1,2),목(5)' -> one block per run of consecutive periods on a weekday."""
    out = []
    for day, nums in re.findall(r'([월화수목금토일])\(([\d,]+)\)', text):
        ps = [int(n) for n in nums.split(',')]
        run = [ps[0]]
        for p in ps[1:] + [None]:
            if p is not None and p == run[-1] + 1:
                run.append(p)
                continue
            m = {'weekday': WEEKDAYS.index(day) + 1,
                 'startMinute': 480 + 60 * run[0], 'endMinute': 540 + 60 * run[-1]}
            if room:
                m['classroom'] = room
            out.append(m)
            if p is not None:
                run = [p]
    assert re.sub(r'[월화수목금토일]\([\d,]+\)', '', text).strip(',') == '', text
    return out


assert meetings('월(1,2),목(5,6,8,9)', 'R') == [
    {'weekday': 1, 'startMinute': 540, 'endMinute': 660, 'classroom': 'R'},
    {'weekday': 4, 'startMinute': 780, 'endMinute': 900, 'classroom': 'R'},
    {'weekday': 4, 'startMinute': 960, 'endMinute': 1080, 'classroom': 'R'},
]
assert meetings('토(0)', '') == [{'weekday': 6, 'startMinute': 480, 'endMinute': 540}]
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
# (canonical name, sheet label, college column, keyword in the official filename)
FILES = [
    ('1-general.xlsx', '교양교과목', None, '교양교과목'),
    ('2-major.xlsx', '전공교과목', 0, '전공교과목'),
    ('3-elective-teaching.xlsx', '일반선택 및 교직교과목', 0, '일반선택'),
]


def resolve(src, name, keyword):
    """Canonical name if present, else the single official Korean-named xlsx."""
    src = Path(src)
    if (src / name).is_file():
        return src / name
    found = sorted(p for p in src.glob('*.xlsx') if keyword in p.name and not p.name.startswith('~$'))
    if len(found) != 1:
        raise FileNotFoundError(f'{src}: expected exactly one xlsx for {keyword!r} or {name}, found {len(found)}')
    return found[0]


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
    for name, sheet, college_col, keyword in FILES:
        data = rows(resolve(src, name, keyword))
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
            slots = meetings(time, get('강의실')) if time else []
            status = 'scheduled' if slots else 'unscheduled'
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
                'remarks': remarks + (f' | {PERIOD_EVIDENCE}' if time else ''),
                'period': PERIOD, 'scheduleStatus': status, 'schedules': slots,
            }
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
