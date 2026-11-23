#!/usr/bin/env python3
"""Build Konyang University 2026-2 timetable datasets (partial scope).

Source (no login): the public syllabus list
  https://www.konyang.ac.kr/prog/sueopgyehoek/kor/sub06_01_04_02/list.do
  POST gaeseol_year=2026, gaeseol_hakgi=2, pageUnit=2000 (one page, 1,564 rows)
and the attached syllabus files (HWP) served from tis.kyu.ac.kr
(FileController.do; that host has no robots.txt rule; fetched once each,
1.2 s apart). The full SmartKY course-opening query needs a student login
and is not used.

Rules
- Original values (course name, professor, classification, the syllabus
  "수업시간" text) are kept verbatim. No classroom is published.
- Rows without an attached syllabus, or whose syllabus has no 수업시간
  value, are "unscheduled" (no published clock).
- Period numbers use the official period table printed in the school's
  2026 syllabus template:
    "[글로컬캠퍼스 수업시간] 1교시(09:30~10:20) 2교시(10:30~11:20) ~
     7교시(15:30~16:20), 8교시(16:30~17:20)"
    "[메디컬캠퍼스 수업시간] 1교시(09:00~09:50) 2교시(10:00~10:50) ~
     7교시(15:00~15:50), 8교시(16:00~16:50)"
  Slot = period start to next period start (50 min class + 10 min = 60 min);
  periods after 8 continue with the same 60-minute slot.
- Campus: explicit "(글로컬캠퍼스)/(메디컬캠퍼스)" in the 수업시간 text, else
  the department's campus on the official campus pages
  (/kor/sub03_01_01.do 메디컬캠퍼스, /kor/sub03_01_03.do 글로컬캠퍼스, the
  창의융합계열 homepage footer "글로컬캠퍼스 : 충청남도 논산시"), "(대전)"
  offering labels = 메디컬캠퍼스, 교양학부 = 글로컬캠퍼스 (휴머니티칼리지 소개
  "위치 : 글로컬캠퍼스 명곡정보관 1층", buseo_cd=32200000) and 교직과정 =
  글로컬캠퍼스 (교직부 https://teaching.konyang.ac.kr/ "글로컬캠퍼스 : 32992
  충청남도 논산시 대학로 121 건양대학교 명곡정보관 1층 교학처 교직부"). Anything else stays campus "unknown"; period-only times there
  cannot pick a period table and stay "unrecognized".
- Direct HH:mm clocks are used as written. Text that the parser does not
  fully understand keeps its original text and becomes "unscheduled"
  (orchestrator decision on PR 1246); only a missing campus table or an
  unreadable attachment format stays "unrecognized".
- 학석사연계 rows (graduate fast-track courses) are excluded (skill rule 10).

Usage (repository root):
  python3 -I tool/timetable/import_konyang.py work/tt-konyang
"""

import hashlib
import html
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hwp_text  # noqa: E402

LIST_URL = 'https://www.konyang.ac.kr/prog/sueopgyehoek/kor/sub06_01_04_02/list.do'
MEDICAL_URL = 'https://www.konyang.ac.kr/kor/sub03_01_01.do'
GLOCAL_URL = 'https://www.konyang.ac.kr/kor/sub03_01_03.do'
PRIME_URL = 'https://primecics.konyang.ac.kr/'
PERIOD_START = {'glocal': 9 * 60 + 30, 'medical': 9 * 60}
CAMPUS_NAMES = {'glocal': '글로컬캠퍼스', 'medical': '메디컬캠퍼스', 'unknown': '캠퍼스 미표기'}

MEDICAL = {
    '의학과', '데이터의학과', '간호학과', '작업치료학과', '병원경영학과', '안경광학과',
    '임상병리학과', '방사선학과', '치위생학과', '물리치료학과', '응급구조학과', '의공학과',
    '의료IT공학과', '의료공간디자인학과', '의료신소재학과', '제약생명공학과', '인공지능학과',
    '교양학부(대전)', '교직과정(대전)',
}
GLOCAL = {
    '스마트보안학과', '기업소프트웨어학부', '국방XR학부', '스마트팜학부', '유무인항공학과',
    '국방반도체공학과', 'ND산업디자인학부', '방위산업공학부', '국방산업경영학부',
    '임상의약바이오학과', '식품생명공학과', '휴먼사이언스학부', '심리상담치료학과', '유아교육과',
    '재활퍼스널트레이닝학과', '국방경찰행정학부', '군사학과', '사회복지학과', '특수교육과',
    '융합디자인학과', '임상의약학과', '의약바이오학과', '드론기계학과', '융합IT학과',
    '교양학부', '교직과정',
}
# Newer official notice wins over the syllabus (nttId=290996, 2026-07-20,
# 휴머니티칼리지): "기존 금요일 6,7교시 → 변경 화요일 10,11교시".
OVERRIDES = {'00042K-01': '화요일 10,11교시', '00025H-01': '화요일 10,11교시'}
OVERRIDE_URL = 'https://www.konyang.ac.kr/cop/bbs/BBSMSTR_000000000584/selectBoardArticle.do?nttId=290996'
WEEKDAYS = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7}


def campus_of_department(dept):
    if dept in MEDICAL:
        return 'medical'
    if dept in GLOCAL:
        return 'glocal'
    return 'unknown'


def parse_rows(page):
    body = page[page.find('<tbody>', page.find('board_total')):]
    body = re.sub(r'<!--[\s\S]*?-->', '', body[:body.find('</tbody>')])
    rows = []
    for tr in re.findall(r'<tr>\s*(<td[\s\S]*?)</tr>', body):
        tds = re.findall(r'<td[^>]*>([\s\S]*?)</td>', tr)
        if len(tds) < 8:
            continue
        m = re.match(r'([\s\S]*?)<br\s*/?>\s*\[([^\]]*)\]', tds[1].strip())
        if not m:
            raise ValueError('unexpected course cell: %r' % tds[1])
        href = re.search(r'href="([^"]*)"', tds[7])
        rows.append({
            'classification': html.unescape(tds[0].strip()),
            'name': html.unescape(m.group(1)).strip(),
            'code': m.group(2).strip(),
            'section': tds[2].strip(),
            'process': tds[3].strip(),
            'creditSystem': tds[4].strip(),
            'professor': html.unescape(tds[5].strip()),
            'department': html.unescape(tds[6].strip()),
            'syllabusUrl': html.unescape(href.group(1)) if href else '',
        })
    total = re.search(r'총게시물 :</span><span class="bold">([\d,]+)', page)
    if not total or int(total.group(1).replace(',', '')) != len(rows):
        raise ValueError('row count does not match the published total')
    return rows


LABELS = {'선수/후수과목', '수업형태', '교과코드', '수강대상', '담당교수', '상담기간', '전자우편'}


def _campus_hint(line):
    if '메디컬' in line or '대전' in line:
        return 'medical'
    if '글로컬' in line or '논산' in line:
        return 'glocal'
    return None


TRAILING = re.compile(r'\s*(선수\s*/\s*후수.*|S\s*D\s*G\s*s.*)$')
INLINE = re.compile(r'^(?:수\s*업\s*시\s*간|강\s*의\s*시\s*간)\s+((?:[\(\[월화수목금토일대죽\d]|Mon|Tue|Wed|Thu|Fri).*)$')


def _value(text):
    text = TRAILING.sub('', text).strip()
    return None if not text or text.replace(' ', '') in LABELS else text


def class_time(paragraphs):
    """Return (수업시간 text, campus written in the syllabus) from the known templates."""
    ps = [p.strip() for p in paragraphs if p.strip()]
    for i, p in enumerate(ps):
        key = p.replace(' ', '')
        if key in ('수업시간', '강의시간', '강의실및강의시간') and i + 1 < len(ps):
            return _value(ps[i + 1]), None
        if key == '강의시간및장소':
            lines = []
            for q in ps[i + 1:]:
                if q.replace(' ', '') in LABELS or not re.match(r'[월화수목금토일]', q):
                    break
                lines.append(q)
            return (', '.join(lines) or None), None
        inline = INLINE.match(p)  # PDF text keeps label and value on one line
        if inline:
            return _value(inline.group(1)), None
    # DYC template: "<campus>" line, then the class time, then "과정명".
    for i, p in enumerate(ps[:8]):
        if p.replace(' ', '') == '과정명' and i >= 2:
            hint = _campus_hint(ps[i - 2]) or _campus_hint(ps[i - 3] if i >= 3 else '')
            return ps[i - 1], hint
    return None, None


def document_paragraphs(path, data):
    """Paragraph texts of a syllabus attachment, or None when the format is unreadable."""
    import io
    import zipfile
    if data[:4] == b'%PDF':
        txt = path + '.txt'
        if not os.path.exists(txt):
            subprocess.run(['swift', os.path.join(HERE, 'pdf_text.swift'), path], check=True)
        with open(txt, encoding='utf-8') as f:
            return f.read().split('\n')
    if data[:4] == b'PK\x03\x04':
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            names = z.namelist()
        if 'word/document.xml' in names:
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                xml = z.read('word/document.xml').decode('utf-8')
            return [re.sub(r'<[^>]+>', '', p) for p in re.findall(r'<w:p[ >][\s\S]*?</w:p>', xml)]
        if any(re.fullmatch(r'Contents/section\d+\.xml', n) for n in names):
            return hwp_text.paragraphs(data)
        return None
    if data[:8] == b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1':
        return hwp_text.paragraphs(data)
    return None


DAY = r'\(?([월화수목금토일]|Mon|Tue|Wed|Thu|Fri|Sat|Sun)(?:요일)?\)?'
CLOCK = r'(\d{1,2})\s*:\s*(\d{2})'
ENGLISH = {'Mon': '월', 'Tue': '화', 'Wed': '수', 'Thu': '목', 'Fri': '금', 'Sat': '토', 'Sun': '일'}
CAMPUS_MARK = {'글로컬캠퍼스': 'glocal', '메디컬캠퍼스': 'medical', '논산': 'glocal', '대전': 'medical',
               '논산캠퍼스': 'glocal', '대전캠퍼스': 'medical'}


def for_section(text, section):
    """Keep the part written for this section: "1분반 수(2,3,4) 2분반 수(6,7,8)", "월(1,2) 01반 / 수(3,4) 02반"."""
    parts = re.findall(r'(\d+)분반\s*(.+?)(?=\s*\d+분반|$)', text)
    if not parts:
        parts = [(n, v) for v, n in re.findall(r'\s*/?\s*(.+?)\s*(\d+)반(?=\s*/|$)', text)]
    if not parts:
        return text
    for number, value in parts:
        if int(number) == int(section):
            return value.strip()
    raise ValueError('no time for this section')


class NoClock(ValueError):
    """The text names no weekday or clock at all ('[시수]', 'TBA', '3시수')."""


def meetings(text, campus, hours=None):
    """Return (campus, [(weekday, start, end)]) or raise ValueError."""
    t = text.strip()
    bare = t.replace('시수', '')  # "[시수]", "3시수" are credit-hour words, not 수요일
    if not re.search(r'[월화수목금토일]|Mon|Tue|Wed|Thu|Fri|Sat|Sun', bare) and not re.search(CLOCK, bare):
        raise NoClock('no weekday or clock')
    explicit = re.match(r'^[\(\[]\s*(글로컬캠퍼스|메디컬캠퍼스|대전캠퍼스|논산캠퍼스)\s*[\)\]]\s*', t)
    if explicit:
        campus = CAMPUS_MARK[explicit.group(1)]
        t = t[explicit.end():]
    # "(논산) 월5,6 (대전) 목 5,6": each campus mark selects the table that follows.
    t = re.sub(r'^(?:대캠|대전캠퍼스)\s*,\s*', '(대전) ', t)
    room = re.match(r'^([^월화수목금토일/]*관[^월화수목금토일/]*)/\s*', t)  # "죽헌정보관 605호/ 월 5,6,7"
    if room:
        t = t[room.end():]
    t = t.replace('·', ',')
    marks = re.split(r'\((논산|대전)\)', t)
    segments = [(campus, marks[0])] + [(CAMPUS_MARK[marks[i]], marks[i + 1]) for i in range(1, len(marks), 2)]
    if len(segments) > 1 and not segments[0][1].strip():
        segments = segments[1:]
        campus = segments[0][0]
    # Run-together period digits ("화12/목78") are split only when some run cannot be one period.
    split_runs = any(int(x) > 14 for x in re.findall(r'(?<![\d:])(\d{2,})(?![\d:])', t))
    out = []
    period_count = 0
    shared = False
    for seg_campus, seg in segments:
        parts = list(re.finditer(DAY, seg))
        if not parts or seg[:parts[0].start()].strip(' ,/'):
            raise ValueError('no leading weekday')
        specs = []
        for k, m in enumerate(parts):
            spec = seg[m.end():parts[k + 1].start() if k + 1 < len(parts) else len(seg)]
            specs.append(spec.strip().strip(',/;:').strip().lstrip('-:/').strip())
        # "월,수 3,4교시": a weekday joined to the next one only by "," or "·" shares
        # its periods. Anything less explicit ("월 수/5, /1~2") is not guessed.
        # "월 수/5, /1~2": bare weekdays then one "/"-separated period group per
        # weekday pair up in order (월=5, 수=1~2); the hours check below confirms it.
        if len(specs) > 1 and not any(specs[:-1]) and '/' in specs[-1]:
            groups = [g.strip(' ,') for g in specs[-1].split('/')]
            if len(groups) != len(specs) or not all(groups):
                raise ValueError('weekday and period groups do not pair')
            specs = groups
            shared = True
        for k in range(len(specs) - 2, -1, -1):
            between = seg[parts[k].end():parts[k + 1].start()]
            if not specs[k] and re.fullmatch(r'\s*[,·]\s*', between) and '/' not in specs[k + 1]:
                specs[k] = specs[k + 1]
                shared = True
        for k, m in enumerate(parts):
            spec = specs[k]
            day = WEEKDAYS[ENGLISH.get(m.group(1), m.group(1))]
            # "1교시 9:30 ~ 10:20" or "3교시(11:30-12:30)": the written clock wins.
            clocks = re.fullmatch(r'(?:[\d\s,~\-]*교시)?\s*\(?\s*%s\s*[~\-]\s*%s\s*\)?' % (CLOCK, CLOCK), spec)
            if clocks:
                h1, m1, h2, m2 = map(int, clocks.groups())
                out.append((day, h1 * 60 + m1, h2 * 60 + m2))
                continue
            body = re.sub(r'\s*교시\s*$', '', spec).strip()
            body = re.sub(r'^\((.*?)\)+$', r'\1', body)
            periods = []
            for chunk in re.split(r'\s*[,./]\s*', body):
                if not chunk:
                    continue
                r = re.fullmatch(r'(\d{1,2})\s*(?:교시)?\s*(?:[~\-]\s*(\d{1,2})\s*(?:교시)?)?', chunk)
                if re.fullmatch(r'\d{1,2}(?:-\d{1,2}){2,}', chunk):  # "7-8-9교시"
                    periods.extend(int(c) for c in chunk.split('-'))
                    continue
                if split_runs and re.fullmatch(r'\d{2,}', chunk):
                    periods.extend(int(c) for c in chunk)
                    continue
                if not r:
                    raise ValueError('unparsed period text %r' % spec)
                a = int(r.group(1))
                b = int(r.group(2) or a)
                if not 1 <= a <= b <= 14:
                    raise ValueError('period out of range %r' % chunk)
                periods.extend(range(a, b + 1))
            if not periods:
                raise ValueError('weekday without period %r' % spec)
            if max(periods) >= 10 and sorted(periods) != list(range(min(periods), max(periods) + 1)):
                raise ValueError('ambiguous period list %r' % spec)  # "목(13,7,8)" 
            period_count += len(periods)
            if seg_campus not in PERIOD_START:
                raise ValueError('campus unknown; period table cannot be chosen')
            for p in periods:
                start = PERIOD_START[seg_campus] + (p - 1) * 60
                out.append((day, start, start + 60))
    for day, s, e in out:
        if not 0 <= s < e <= 1440:
            raise ValueError('invalid clock')
    if shared and hours is not None and period_count != hours:
        # "월,수 3,4교시" on a 2-hour course: n weekdays and n periods pair up in order.
        listed = re.fullmatch(r'\s*((?:[월화수목금토일](?:요일)?\s*[,·]\s*)+[월화수목금토일](?:요일)?)'
                              r'\s*\(?([\d\s,]+?)\)?\s*(?:교시)?\s*', t)
        if listed:
            days = re.findall(r'[월화수목금토일]', listed.group(1))
            periods = [p for p in re.split(r'\s*,\s*', listed.group(2).strip()) if p]
            if len(days) == len(periods) == hours:
                return meetings(', '.join(d + ' ' + p for d, p in zip(days, periods)), campus, hours)
        raise ValueError('shared periods do not match weekly hours')
    return campus, merge(out)


def merge(items):
    items = sorted(set(items))
    merged = []
    for day, s, e in items:
        if merged and merged[-1][0] == day and s - merged[-1][2] < 60 and s >= merged[-1][1]:
            merged[-1] = (day, merged[-1][1], max(e, merged[-1][2]))
        else:
            merged.append((day, s, e))
    return merged


def main(work):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    page_path = os.path.join(work, 'raw', 'all.html')
    with open(page_path, encoding='utf-8') as f:
        page = f.read()
    rows = parse_rows(page)
    datasets = {c: [] for c in CAMPUS_NAMES}
    excluded = []
    empty_files = []
    legacy_files = []
    reasons = {}
    for row in rows:
        dept = row['department']
        if row['classification'] == '학석사연계':
            excluded.append(row['code'] + '-' + row['section'])
            continue
        campus = campus_of_department(dept)
        text = None
        if row['syllabusUrl']:
            path = os.path.join(work, 'hwp', os.path.basename(
                re.search(r'filePath=([^&]*)', row['syllabusUrl']).group(1)))
            with open(path, 'rb') as f:
                data = f.read()
            # The server answers some attachment links with an empty body.
            paragraphs = document_paragraphs(path, data) if data else []
            legacy = paragraphs is None  # HWP 3.0, PowerPoint: not readable here
            text, hint = class_time(paragraphs) if paragraphs else (None, None)
            if legacy:
                legacy_files.append(row['code'] + '-' + row['section'])
            if hint:
                campus = hint
            if not data:
                empty_files.append(row['code'] + '-' + row['section'])
        override = OVERRIDES.get(row['code'] + '-' + row['section'])
        if override:
            text = override
        schedules, status = [], 'unscheduled'
        note = '공개 수업계획서 목록에 첨부 수업계획서가 없어 수업 시각을 확인할 수 없습니다.'
        if row['syllabusUrl']:
            note = '공개 수업계획서에 수업시간이 적혀 있지 않습니다.'
            if empty_files and empty_files[-1] == row['code'] + '-' + row['section']:
                note = '공개 수업계획서 첨부 파일이 비어 있어 수업 시각을 확인할 수 없습니다.'
        if legacy_files and legacy_files[-1] == row['code'] + '-' + row['section']:
            status = 'unrecognized'
            note = '첨부 수업계획서 형식(HWP 3.0·PowerPoint)을 읽지 못해 수업시간을 확인하지 못했습니다. 시간표에 추가할 수 없습니다.'
        if text:
            try:
                theory, practice = (int(x) for x in row['creditSystem'].split('-')[1:3])
                campus, found = meetings(for_section(text, row['section']), campus,
                                         hours=theory + practice)
                schedules = [{'weekday': d, 'startMinute': s, 'endMinute': e, 'classroom': ''}
                             for d, s, e in found]
                status = 'scheduled'
                note = '공개 수업계획서의 수업시간 기준입니다. 강의실은 공개 자료에 없습니다.'
                if override:
                    note = ('2026-07-20 학교 공지(연합교양대학 수업 시간표 변경 안내) 기준입니다: '
                            '기존 금요일 6,7교시 → 화요일 10,11교시. 강의실은 공개 자료에 없습니다.')
            except NoClock:
                pass
            except ValueError as error:
                key = re.sub(r" '.*", '', str(error))
                reasons[key] = reasons.get(key, 0) + 1
                if 'campus unknown' in str(error):
                    status = 'unrecognized'
                    note = '캠퍼스가 공개 자료에 없어 교시 시각을 정할 수 없습니다. 원문 수업시간만 표시합니다.'
                else:
                    # Orchestrator decision (PR 1246): unreadable notation is "time undecided".
                    note = '원문 수업시간 표기를 교시로 해석할 수 없어 시간 미정 강좌로 추가할 수 있습니다. 원문 표기를 확인하세요.'
                    if 'weekly hours' in str(error) or 'do not pair' in str(error):
                        note = ('원문 수업시간의 요일·교시 대응이 학점-이론-실습 시수와 맞지 않아 '
                                '시간 미정 강좌로 추가할 수 있습니다. 원문 표기를 확인하세요.')
        credit = float(row['creditSystem'].split('-')[0])
        course = {
            'sourceId': 'konyang/%s/2026/2/%s-%s' % (campus, row['code'], row['section']),
            'campus': campus,
            'academicYear': 2026,
            'semester': '2',
            'courseCode': row['code'],
            'section': row['section'],
            'courseName': row['name'],
            'professor': row['professor'],
            'credits': credit,
            'departments': [dept],
            'classification': row['classification'],
            'departmentCredits': {dept: credit},
            'departmentClassifications': {dept: row['classification']},
            'departmentRemarks': {dept: '학점-이론-실습: %s\n%s' % (row['creditSystem'], note)},
            'sourceSchedule': text or '',
            'sourceClassroom': '',
            'scheduleStatus': status,
            'schedules': schedules,
        }
        datasets[campus].append(course)
    with open(os.path.join(work, 'raw', 'hashes.json'), 'w') as f:
        json.dump({'list': hashlib.sha256(page.encode('utf-8')).hexdigest()}, f)
    summary = {}
    for campus, courses in datasets.items():
        counts = {}
        for c in courses:
            counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
        data = {
            'schemaVersion': 1,
            'universityId': 'konyang',
            'campus': campus,
            'campusName': CAMPUS_NAMES[campus],
            'academicYear': 2026,
            'semester': '2',
            'publishedDate': '2026-11-23',
            'sourceUrl': LIST_URL,
            'sourceNotice': '공개 수업계획서 조회(2026학년도 2학기) 목록과 첨부 수업계획서 기준 부분 자료입니다.',
            'researchOnly': False,
            'productionIntegrationEnabled': True,
            'completionClaim': False,
            'wholeOperatingVerified': False,
            'sourceRowCount': len(rows),
            'excludedGraduateRows': excluded,
            'emptySyllabusFiles': empty_files,
            'unreadableSyllabusFiles': legacy_files,
            'courseScheduleStatusCounts': counts,
            'sourceHashes': {'syllabusList': hashlib.sha256(page.encode('utf-8')).hexdigest()},
            'periodEvidence': {
                'source': '건양대학교 2026학년도 2학기 공개 수업계획서 양식(첨부 hwp) 학사관련 안내',
                'glocal': '[글로컬캠퍼스 수업시간] 1교시(09:30~10:20) 2교시(10:30~11:20) ~ 7교시(15:30~16:20), 8교시(16:30~17:20)',
                'medical': '[메디컬캠퍼스 수업시간] 1교시(09:00~09:50) 2교시(10:00~10:50) ~ 7교시(15:00~15:50), 8교시(16:00~16:50)',
                'slotMinutes': 60,
            },
            'campusEvidence': {'medical': MEDICAL_URL, 'glocal': [GLOCAL_URL, PRIME_URL]},
            'courses': courses,
        }
        out = os.path.join(root, 'assets', 'timetable', 'konyang-%s-2026-2.json' % campus)
        with open(out, 'w', encoding='utf-8') as f:
            f.write(json.dumps(data, ensure_ascii=False, separators=(',', ':')))  # compact, no trailing newline (minify_assets.py --check)
        summary[campus] = (len(courses), counts)
    print(json.dumps({'rows': len(rows), 'excluded': len(excluded), 'emptyFiles': len(empty_files), 'datasets': summary,
                      'unrecognizedReasons': reasons}, ensure_ascii=False, indent=1))


def _self_check():
    assert meetings('화(2,3),금(2)', 'glocal')[1] == [(2, 630, 750), (5, 630, 690)]
    assert meetings('(메디컬캠퍼스) 월요일 5교시', 'unknown') == ('medical', [(1, 780, 840)])
    assert meetings('화요일 2-3교시, 수요일 5교시', 'medical')[1] == [(2, 600, 720), (3, 780, 840)]
    assert meetings('(글로컬캠퍼스) 목요일 1교시 9:30 ~ 10:20', 'unknown') == ('glocal', [(4, 570, 620)])
    assert meetings('화요일 3교시/ 수요일 3교시(11:30-12:30)', 'glocal')[1] == [(2, 690, 750), (3, 690, 750)]
    assert meetings('수 1, 2 / 목 5', 'glocal')[1] == [(3, 570, 690), (4, 810, 870)]
    assert meetings('목 5-6 / 7-8', 'glocal')[1] == [(4, 810, 1050)]
    assert meetings('화12/목78', 'glocal')[1] == [(2, 570, 690), (4, 930, 1050)]
    assert meetings('(논산) 월5,6 (대전) 목 5,6', 'medical') == ('glocal', [(1, 810, 930), (4, 780, 900)])
    assert meetings('Mon 7,8,9', 'medical')[1] == [(1, 900, 1080)]
    assert meetings('(화)1,2,3', 'glocal')[1] == [(2, 570, 750)]
    assert meetings('수(3,4), 금(2,.3)', 'glocal')[1] == [(3, 690, 810), (5, 630, 750)]
    assert meetings('월-6교시, 수-1,2,3,4교시', 'glocal')[1] == [(1, 870, 930), (3, 570, 810)]
    assert meetings('월(2,3), 목(2,3))', 'glocal')[1] == [(1, 630, 750), (4, 630, 750)]
    assert meetings('화요일 : 6.7.8 교시', 'glocal')[1] == [(2, 870, 1050)]
    assert meetings('화 7-8-9교시, 목 7교시', 'glocal')[1] == [(2, 930, 1110), (4, 930, 990)]
    assert meetings('월/5.6 수/6', 'medical')[1] == [(1, 780, 900), (3, 840, 900)]
    assert class_time(['강의시간 및 장소', '화 1, 2교시', '수 3교시,', '담당교수']) == ('화 1, 2교시, 수 3교시,', None)
    assert class_time(['DYC 수업계획서', '논산 글로컬캠퍼스', '화요일 : 6.7.8 교시', '과정명']) == ('화요일 : 6.7.8 교시', 'glocal')
    assert meetings('월,수 3,4교시', 'glocal')[1] == [(1, 690, 810), (3, 690, 810)]
    assert meetings('월,수 3,4교시', 'glocal', hours=4)[1] == [(1, 690, 810), (3, 690, 810)]
    assert meetings('월 수/5, /1~2', 'medical', hours=3)[1] == [(1, 780, 840), (3, 540, 660)]
    assert meetings('월,수 3,4교시', 'medical', hours=2)[1] == [(1, 660, 720), (3, 720, 780)]
    for unclear, hours in (('월 수/5, /1~2', 4), ('월,수 3,4교시', 3), ('월 수 목/5, /1~2', 3)):
        try:
            meetings(unclear, 'glocal', hours=hours)
            raise AssertionError(unclear)
        except NoClock:
            raise AssertionError(unclear)
        except ValueError:
            pass
    assert meetings('화요일 5,6,7교시 (13:30~16:30)', 'glocal')[1] == [(2, 810, 990)]
    assert meetings('죽헌정보관 605호/ 월 5,6,7 목 1,2,3', 'medical')[1] == [(1, 780, 960), (4, 540, 720)]
    assert meetings('대캠, 화(7, 8, 9)', 'glocal') == ('medical', [(2, 900, 1080)])
    assert class_time(['수 업 시 간 (글로컬캠퍼스) 목요일 5교시 S D G s 목 표 8번']) == ('(글로컬캠퍼스) 목요일 5교시', None)
    assert class_time(['수업시간 화(2,3,4) 선수/후수']) == ('화(2,3,4)', None)
    assert class_time(['수업시간에 질의는 자유롭게']) == (None, None)
    assert for_section('1분반 수(2,3,4) 2분반 수(6,7,8)', '02') == '수(6,7,8)'
    assert for_section('월(1,2) 01반 / 수(3,4) 02반', '01') == '월(1,2)'
    assert meetings('(대전캠퍼스) 월요일 2교시', 'unknown') == ('medical', [(1, 600, 660)])
    assert class_time(['수업시간 중 진행되는 토론']) == (None, None)
    for none in ('[시수]', '3시수', 'TBA', '3시간'):
        try:
            meetings(none, 'glocal')
            raise AssertionError(none)
        except NoClock:
            pass
    for bad in ('수요일 7교시  00087M(43)', '울(6,7), 수(3)'):
        try:
            meetings(bad, 'glocal')
            raise AssertionError(bad)
        except ValueError:
            pass


if __name__ == '__main__':
    _self_check()
    main(sys.argv[1])
