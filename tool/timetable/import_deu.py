#!/usr/bin/env python3
"""Build Dong-eui University (deu) 2026-2 from its official 1st-year course PDFs.

Sources (학부 공지 https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=88345,
2026-08-13): 계열·균형교양 (attachNo=138760), 전공 (138761), 공통교양 (138762),
all titled "1학년 수강과목". Closures: 개강 전 폐강강좌현황 전공/교양 xlsx
(https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=90692, 2026-08-27).

    python3 -I tool/timetable/import_deu.py <a.pdf> <b.pdf> <c.pdf> <closeM.xlsx> <closeG.xlsx> <out.json>

PDF text is read with macOS PDFKit through tool/timetable/daegu_pdf_columns.swift
(PyMuPDF is not installed here). The school publishes no 교시→시각 table for
undergraduate classes as a table; the 2026-2 출석인정 manual's DAP screen gives
"09:00 1교시" and "23:50 15교시" (see FIRST_PERIOD_MINUTE), so [월1-3] becomes
Monday 09:00-12:00 (60-minute slots). A cell clipped mid-slot stays
`unrecognized`; a row without a weekday/period is `unscheduled`.
Courses on the official pre-semester closure list stay courses: closure is not
judged (2026-11-23 사용자 결정), a remark notes the listing and
`closureListedCourses` records the 강좌번호.
"""
import collections
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

SWIFT = Path(__file__).with_name('daegu_pdf_columns.swift')
SOURCE_URL = 'https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=88345'
CLOSURE_URL = 'https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=90692'
CLOSURE_DATE = '2026-08-27'
CODE = re.compile(r'^(\d{6})-(\d{3})$')
SLOT = re.compile(r'\[[월화수목금토일][^\]]*\]')
# One printed meeting: optional room, then [요일교시] or [요일교시-교시].
MEETING = re.compile(r'([^\[\],]*)\[([월화수목금토일])(\d+)(?:-(\d+))?\]')
WEEKDAYS = '월화수목금토일'
# Period clock (2026-11-23 research): the 2026-2 출석인정 신청 manual attached to
# the 학사 notice re-posted on department boards (e.g.
# https://deuhome.deu.ac.kr/biopharm/sub06_03.do?mode=view&articleNo=90395,
# 2026-08-24, attachNo=139516 「출석인정 신청 순서 메뉴얼」) shows the DAP 출석인정의뢰
# screen whose period pickers read "09:00 1교시" and "23:50 15교시"; 「강의시간편성및
# 수업규정」 제2조① sets 50-minute classes. 09:00 + 14 x 60 + 50 = 23:50, so period n
# starts 09:00 + (n-1) h and its slot runs 60 minutes (50 class + 10 break).
FIRST_PERIOD_MINUTE = 9 * 60
PERIOD_SLOT_MINUTES = 60
PERIOD_EVIDENCE = ('교시 시각: n교시 = 09:00+(n-1)시간, 60분 슬롯(2026-2 출석인정 신청 순서 메뉴얼 attachNo=139516의 '
                   'DAP 화면 "09:00 1교시"·"23:50 15교시", 「강의시간편성및수업규정」 제2조① 강의 50분)')

# kind -> (column edges, column names, attachNo, PDF title). Edges sit in the
# blank gaps between the printed table columns.
LAYOUTS = {
    'a': ('20,48,92,218,252,338,452,600',
          ['구분', '강좌번호', '교과목명', '학점/시간', '수강대상', '담당교수', '강의'], 138760, '계열·균형교양'),
    'b': ('20,50,108,300,336,384,600',
          ['구분', '강좌번호', '교과목명', '학점/시간', '담당교수', '강의'], 138761, '전공과목'),
    'c': ('10,40,84,203,245,414,460,600',
          ['구분', '강좌번호', '교과목명', '학점/시간', '수강대상', '담당교수', '강의'], 138762, '공통교양'),
}


def pdf_lines(pdf, edges):
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / 'lines.json'
        subprocess.run(['swift', str(SWIFT), str(pdf), str(out), '1', '999', edges],
                       check=True, capture_output=True)
        return json.loads(out.read_text(encoding='utf-8'))


def grouped(lines):
    """Lines of one page grouped into printed rows (same top within 3pt)."""
    rows = []
    for ln in sorted(lines, key=lambda l: (l[2], l[1])):
        if rows and abs(rows[-1][0] - ln[2]) < 3:
            rows[-1][1].append(ln)
        else:
            rows.append([ln[2], [ln]])
    return rows


def table_rows(kind, pdf):
    """Every printed course row: anchor cells plus continuation lines below it."""
    edges, names, attach, _ = LAYOUTS[kind]
    strips = pdf_lines(pdf, edges)
    whole = {p['page']: p['lines'] for p in pdf_lines(pdf, '0,1000')}
    out = []
    heading = None
    for page in strips:
        pno = page['page']
        # 전공 PDF: centred department title followed by "(주간)".
        titles = []
        area = None
        for y, row in grouped(whole[pno]):
            text = ''.join(l[0] for l in sorted(row, key=lambda l: l[1])).strip()
            if kind == 'b' and row[0][1] > 150 and text and text not in ('(주간)', '나. 전공과목') \
                    and not text.startswith('[Ucb') and '구분' not in text:
                titles.append((y, text))
            if kind != 'b' and 50 < y < 65:
                area = ''.join(l[0] for l in row if l[1] > 450).strip() or area
        current = None
        for y, row in grouped(page['lines']):
            if y < 100 or y > 800:
                continue  # page title, legend, header, footer
            cells = collections.defaultdict(list)
            for ln in sorted(row, key=lambda l: l[1]):
                t = ln[0].strip()
                if t and t not in cells[ln[5]]:  # shaded cells print their text twice
                    cells[ln[5]].append(t)
            cells = {names[k]: ' '.join(v) for k, v in cells.items()}
            if kind == 'b':
                above = [t for ty, t in titles if ty < y]
                if above:
                    heading = above[-1]
            if CODE.match(cells.get('강좌번호', '')):
                current = {'kind': kind, 'attachNo': attach, 'page': pno, 'y': round(y, 1),
                           'cells': cells, 'more': [], 'department': heading if kind == 'b' else None,
                           'area': area}
                out.append(current)
            elif kind == 'b':
                joined = ''.join(cells.values())
                if not (joined in ('(주간)', '(주 간)') or '구분' in joined or
                        any(joined.replace(' ', '') == t for _, t in titles)):
                    raise ValueError(f'unexpected 전공 PDF line p{pno} y{y:.0f}: {cells}')
            else:
                if current is None or current['page'] != pno:
                    raise ValueError(f'continuation without row p{pno} y{y:.0f}: {cells}')
                # A taller row prints its extra lines below the code line
                # (top aligned, as on every multi-line row of these PDFs).
                if set(cells) - {'수강대상', '담당교수'}:
                    raise ValueError(f'unexpected continuation p{pno} y{y:.0f}: {cells}')
                current['more'].append(cells)
    return out


def xlsx_rows(path):
    ns = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
    z = zipfile.ZipFile(path)
    shared = [''.join(t.text or '' for t in si.iter(ns + 't'))
              for si in ET.fromstring(z.read('xl/sharedStrings.xml')).iter(ns + 'si')]
    rows = []
    for name in sorted(n for n in z.namelist() if n.startswith('xl/worksheets/sheet')):
        for r in ET.fromstring(z.read(name)).iter(ns + 'row'):
            vals = []
            for c in r.iter(ns + 'c'):
                v = c.find(ns + 'v')
                if c.get('t') == 's':
                    vals.append(shared[int(v.text)])
                elif c.get('t') == 'inlineStr':
                    vals.append(''.join(t.text or '' for t in c.iter(ns + 't')))
                else:
                    vals.append(v.text if v is not None else '')
            rows.append(vals)
    head, body = rows[0], rows[1:]
    if head[:6] != ['교수명', '개설학과', '학년', '이수구분명', '교과목코드', '교과목명']:
        raise ValueError(f'unexpected closure header {head}')
    return [dict(zip(head, r)) for r in body if any(r)]


def audience(label):
    """수강대상 '미래모빌리티학과(1)' -> ('미래모빌리티학과', '1'); a clipped cell keeps its text."""
    m = re.match(r'^(.*)\((\d)\)$', label)
    if m:
        return m.group(1), m.group(2)
    return label.rstrip('('), None


def meetings(lecture):
    """'2인207[화4],[수2-3](50)' -> merged weekly meetings; None when the printed
    cell is clipped mid-slot (an unclosed '['), so nothing is guessed."""
    body = re.sub(r'\(\d*$|\(\d+\)$', '', lecture.strip())
    if body.count('[') != body.count(']'):
        return None
    out = []
    room = ''
    for m in MEETING.finditer(body):
        room = m.group(1).strip() or room  # '[수2-3]' after '2인207[화4]' keeps the room
        first, last = int(m.group(3)), int(m.group(4) or m.group(3))
        start = FIRST_PERIOD_MINUTE + (first - 1) * PERIOD_SLOT_MINUTES
        end = FIRST_PERIOD_MINUTE + last * PERIOD_SLOT_MINUTES
        meeting = {'weekday': WEEKDAYS.index(m.group(2)) + 1, 'startMinute': start, 'endMinute': end,
                   'classroom': room}
        prev = out[-1] if out else None
        if (prev and prev['weekday'] == meeting['weekday'] and prev['classroom'] == room
                and 0 <= start - prev['endMinute'] < 60):
            prev['endMinute'] = max(prev['endMinute'], end)
        else:
            out.append(meeting)
    return out


def build(rows, closures):
    closed = {r['교과목코드']: r for r in closures}
    courses = {}
    excluded = set()
    for row in rows:
        c = row['cells']
        key = c['강좌번호']
        if key in closed:
            excluded.add(key)
        code, section = CODE.match(key).groups()
        title = c['교과목명']
        grade = None
        if row['kind'] == 'b':
            m = re.match(r'^(\d)\s+(.+)$', title)
            if not m:
                raise ValueError(f'major row without grade {c}')
            grade, title = m.groups()
        credit, hours = c['학점/시간'].split('/')
        professor = c.get('담당교수', '') + ''.join(m.get('담당교수', '') for m in row['more'])
        lecture = c.get('강의', '')
        if row['kind'] == 'b':
            targets = [(row['department'], grade, row['department'])]
        else:
            labels = [c.get('수강대상', '')] + [m['수강대상'] for m in row['more'] if '수강대상' in m]
            targets = []
            for raw in labels:
                name, g = audience(raw)
                targets.append((name, g, raw))
        slots = SLOT.findall(lecture)
        rooms = re.sub(r'\(\d+\)$', '', SLOT.sub('', lecture)).strip(' ,')
        capacity = re.search(r'\((\d+)\)$', lecture)
        course = courses.get(key)
        if course is None:
            course = courses[key] = {
                'sourceId': f'deu/main/2026/2/{key}',
                'campus': 'main', 'academicYear': 2026, 'semester': '2',
                'courseCode': code, 'section': section, 'courseName': title,
                'professor': professor, 'classification': c['구분'],
                'credits': float(credit), 'departments': [], 'departmentCredits': {},
                'departmentClassifications': {}, 'departmentRemarks': {},
                'sourceSchedule': ','.join(slots), 'sourceClassroom': rooms,
                'remarks': '', 'scheduleStatus': 'unscheduled', 'schedules': [], '_rows': [],
            }
            if slots:
                placed = meetings(lecture)
                course['scheduleStatus'] = 'scheduled' if placed else 'unrecognized'
                course['schedules'] = placed or []
        else:
            for field, value in (('courseName', title), ('professor', professor), ('credits', float(credit)),
                                 ('classification', c['구분']), ('sourceSchedule', ','.join(slots))):
                if course[field] != value:
                    raise ValueError(f'{key} {field} differs: {course[field]!r} vs {value!r}')
        _, _, attach, pdf_title = LAYOUTS[row['kind']]
        where = f'{pdf_title} PDF(attachNo={attach}) {row["page"]}쪽'
        line = f'{where} 원문: 구분 {c["구분"]}, 강의시간 및 강의실(인원) {lecture}'
        if row.get('area'):
            line += f', 영역 {row["area"]}'
        if line not in course['_rows']:
            course['_rows'].append(line)
        for name, g, raw in targets:
            if name not in course['departments']:
                course['departments'].append(name)
            course['departmentCredits'][name] = float(credit)
            course['departmentClassifications'][name] = c['구분']
            note = f'수강대상 원문: {raw}' if row['kind'] != 'b' else f'개설학과 소제목: {raw}, 학년 {g}'
            if raw.endswith('(') or (row['kind'] != 'b' and g is None):
                note += ' (PDF 칸 너비에서 잘린 원문)'
            prev = course['departmentRemarks'].get(name)
            if prev is None:
                course['departmentRemarks'][name] = note
            elif note not in prev.split(' | '):
                course['departmentRemarks'][name] = prev + ' | ' + note
        course['_hours'] = hours
        if capacity:
            course['_capacity'] = capacity.group(1)
    out = []
    for course in courses.values():
        status = {'scheduled': PERIOD_EVIDENCE,
                  'unrecognized': '교시 원문만 표시: PDF 칸에서 강의시간 원문이 잘려 시각으로 바꾸지 않음',
                  'unscheduled': '요일·교시 표기 없음(원격사이버강좌 등)'}[course['scheduleStatus']]
        closure = ([f'개강 전 폐강강좌현황({CLOSURE_DATE})에도 실린 강좌(폐강 여부는 판단하지 않음, 2026-11-23 사용자 결정)']
                   if course['sourceId'].rsplit('/', 1)[1] in excluded else [])
        course['remarks'] = ' | '.join(course.pop('_rows') + [
            f'학점/시간 {course["credits"]:g}/{course.pop("_hours")}', status] + closure)
        course.pop('_capacity', None)
        out.append(course)
    return out, sorted(excluded)


def main(argv):
    a, b, c, close_m, close_g, out = argv
    rows = table_rows('a', a) + table_rows('b', b) + table_rows('c', c)
    closures = xlsx_rows(close_m) + xlsx_rows(close_g)
    courses, excluded = build(rows, closures)
    courses.sort(key=lambda x: x['sourceId'])
    statuses = collections.Counter(x['scheduleStatus'] for x in courses)
    data = {
        'schemaVersion': 2, 'universityId': 'deu', 'campus': 'main', 'campusName': '본교',
        'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-08-13',
        'sourceUrl': SOURCE_URL,
        'sourceNotice': (
            f'동의대학교 학부 공지(2026-08-13) 2026학년도 2학기 1학년 수강과목 PDF 3개(계열·균형교양, 전공, 공통교양) '
            f'{len(rows)}행, 고유 강좌번호 {len(courses)}개. 개강 전 폐강강좌현황({CLOSURE_DATE}, '
            f'{CLOSURE_URL})에 실린 {len(excluded)}강좌도 비고로만 표시하고 그대로 둡니다. 교시는 2026-2 출석인정 신청 '
            f'메뉴얼(attachNo=139516)의 DAP 화면 "09:00 1교시"·"23:50 15교시"와 강의 50분 규정에 따라 '
            f'n교시 = 09:00+(n-1)시간, 60분 슬롯으로 바꿉니다.'),
        'scopeNote': '1학년 수강과목 PDF만 반영했습니다. 2~4학년 전공·교양 강좌는 이 자료에 없습니다.',
        'sourceRowCount': len(rows),
        'sourceHashes': {f'{n} (sha256)': hashlib.sha256(Path(p).read_bytes()).hexdigest()
                         for n, p in (('계열·균형교양 PDF attachNo=138760', a), ('전공 PDF attachNo=138761', b),
                                      ('공통교양 PDF attachNo=138762', c), ('폐강 전공 xlsx attachNo=140140', close_m),
                                      ('폐강 교양·기타 xlsx attachNo=140141', close_g))},
        'courseScheduleStatusCounts': dict(sorted(statuses.items())),
        'closureListedCourses': excluded,
        'researchOnly': False, 'productionIntegrationEnabled': True,
        'completionClaim': False, 'wholeOperatingVerified': False,
        'courses': courses,
    }
    Path(out).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'rows': len(rows), 'courses': len(courses), 'closureListed': excluded,
                      'status': statuses}, ensure_ascii=False))


if __name__ == '__main__':
    main(sys.argv[1:])
