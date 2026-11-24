#!/usr/bin/env python3
"""Current public Hansung catalog: only verified clocks and reviewed operations.

Every source course remains searchable. Unknown dates, mixed-hour allocations,
partial period endpoints and unpublished current plans cannot be added as a
weekly classroom schedule. No full syllabuses or personal contact fields ship.
"""
import argparse
import collections
import html
import json
from pathlib import Path
import re
from datetime import date, timedelta


# Current school rule article 11 and the official current semester calendar.
# School closure days below are never given regular meetings.
REGULAR_START = date(2026, 8, 31)
REGULAR_END = date(2026, 12, 6)
SCHOOL_CLOSURES = {
    date(2026, 9, 24), date(2026, 9, 25), date(2026, 9, 26),
    date(2026, 10, 3), date(2026, 10, 5), date(2026, 10, 9),
}


def regular_teaching_dates(meetings):
    """Derive dates from verified ordinary rules, not printed individual dates."""
    result = []
    day = REGULAR_START
    while day <= REGULAR_END:
        if day not in SCHOOL_CLOSURES:
            for meeting in meetings:
                if meeting['weekday'] == day.isoweekday():
                    result.append({**meeting, 'date': day.isoformat()})
        day += timedelta(days=1)
    return result

# 수강신청 안내 '강의시간 안내' 기준 쉬는 시간 포함 슬롯: 시작부터 다음 교시 시작 직전까지.
# 마지막 교시는 같은 요일 그룹의 일반 슬롯(75분제 90분, 50분제 60분)을 쓴다.
DAY75=[('1','2',540,630),('2M','3M',630,720),('4','5',720,810),('5M','6M',810,900),('7','8',900,990),('8M','9M',990,1080),('10','11',1080,1165),('11M','12M',1165,1245),('13','14',1245,1335)]
NIGHT50={10:(1080,1135),11:(1135,1190),12:(1190,1245),13:(1245,1300),14:(1300,1360)}

def _label_clocks():
    # 사용자 지시(2026-10-25 "다른 교시랑 똑같이 하면 된다"): 경계 라벨은 요일과 무관하게
    # 75분제 블록 → 50분제 교시 → 주간(1~9M) 30분 칸(n=정각, nM=30분) 순서로 같은 시각을 쓴다.
    starts = {b[0]: b[2] for b in DAY75}
    ends = {b[1]: b[3] for b in DAY75}
    for n in range(1, 15):
        s, e = (540 + (n - 1) * 60, 540 + n * 60) if n <= 9 else NIGHT50[n]
        starts.setdefault(str(n), s)
        ends.setdefault(f'{n}M', e)
        if n <= 9:
            starts.setdefault(f'{n}M', s + 30)
            ends.setdefault(str(n), s + 30)
    return starts, ends


LABEL_STARTS, LABEL_ENDS = _label_clocks()


def clock(day, first, last):
    # 토·일도 평일 교시표와 같은 시각·슬롯을 쓴다(2026-10-25 사용자 지시).
    if not 1 <= day <= 7:
        raise ValueError('Invalid weekday')
    if first not in LABEL_STARTS or last not in LABEL_ENDS:
        raise ValueError('Unpublished clock label')
    start, end = LABEL_STARTS[first], LABEL_ENDS[last]
    if start >= end:
        raise ValueError('Reversed clock blocks')
    return start, end


def schedules(raw):
    # Room bindings are parsed per explicit slash-separated segment; no ordering guesses.
    out=[]
    for block in raw.split('/'):
        block=block.strip()
        if re.fullmatch(r'온라인강좌\s+[\d.]+시간', block):
            continue
        match=re.fullmatch(r'(.+?)\s+((?:[월화수목금토일]\d+M?~\d+M?)(?:\s*,\s*[월화수목금토일]\d+M?~\d+M?)*)',block)
        if match is None:
            raise ValueError('Unrecognized whole room/time block')
        room=match[1].strip()
        for part in match[2].split(','):
            m=re.fullmatch(r'([월화수목금토일])(\d+M?)~(\d+M?)',part.strip())
            day='월화수목금토일'.index(m[1])+1
            start,end=clock(day,m[2],m[3])
            out.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
    if any(a['weekday'] == b['weekday'] and a['startMinute'] < b['endMinute']
           and b['startMinute'] < a['endMinute']
           for i, a in enumerate(out) for b in out[i + 1:]):
        raise ValueError('Ambiguous simultaneous Hansung classroom slots')
    return out


def clean(value):
    text = html.unescape(str(value or ''))
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'https?://\S+', '[접속링크 제외]', text)
    text = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[연락처 제외]', text)
    text = re.sub(r'(?<!\d)(?:0\d{1,2}[-. ]?)?\d{3,4}[-. ]\d{4}(?!\d)', '[연락처 제외]', text)
    return re.sub(r'\s+', ' ', text).strip()


def prepare(rows, proofs, neutral):
    if not rows:
        raise ValueError('Empty Hansung current scope')
    groups=collections.defaultdict(list)
    for row in rows:
        if (not re.fullmatch(r'[A-Z0-9]+', row['kwamokcode']) or
                not re.fullmatch(r'[A-Z0-9@]+', row['bunban']) or
                not clean(row['kwamokname']) or not clean(row['departmentName']) or
                not 0 <= float(row['hakjum']) <= 30):
            raise ValueError('Invalid Hansung educational identity')
        groups[(row['kwamokcode'],row['bunban'])].append(row)
    courses = []
    reasons = collections.Counter()
    for (code,section),variants in groups.items():
        r=variants[0]
        p = proofs.get(f'{code}-{section}', {'status':'notChecked'})
        if p['status'] == 'currentVerifiedIdentity' and (
                p.get('academicYear') != 2026 or p.get('semester') != '2' or
                p.get('courseCode') != code or p.get('section') != section or
                # The current catalog adds this administrative credit-term
                # suffix to the same code/section. Keep it in the displayed
                # title; it does not prove actual teaching dates.
                clean(p.get('courseName')) not in {
                    clean(r['kwamokname']),
                    clean(r['kwamokname']).removesuffix('(상상더학기)'),
                }):
            raise ValueError('Current Hansung plan identity conflict')
        for v in variants:
            if any(v[f]!=r[f] for f in ['kwamokname','hakjum','prof','classroom','bigo']):
                raise ValueError('Core educational aliases conflict')
        departments = []
        classifications = {}
        credits = {}
        remarks = {}
        for v in variants:
            dep=re.sub(r'^\[[A-Z0-9]+\]\s*','',v['departmentName']).strip()
            if dep not in departments:
                departments.append(dep)
            classifications[dep] = clean(v['isugubun'])
            credits[dep] = float(v['hakjum'])
            note=[clean(v['bigo'])] if clean(v['bigo']) else []
            if clean(v['haknean']):
                note.append('대상 학년: ' + clean(v['haknean']))
            if clean(v['haknean_limit']):
                note.append('학년 제한(원문): ' + clean(v['haknean_limit']))
            if v['excl_ext_stu'] == '1':
                note.append('타교생 수강 제외(공식 원표)')
            if p['status'] == 'currentVerifiedIdentity':
                for label, field in [('계획서 수강대상', 'sourceTarget'),
                                     ('선수·사전이수 안내', 'sourcePrerequisites')]:
                    if clean(p.get(field)):
                        note.append(label + ': ' + clean(p[field]))
            remarks[dep]='\n'.join(note)
        parsed = []
        status = 'unrecognized'
        reason = ''
        raw=clean(r['classroom'])
        if not raw or re.fullmatch(r'온라인강좌\s+[\d.]+시간|사이버',raw):
            status='unscheduled'
        else:
            try:
                source_meetings = schedules(raw)
            except ValueError as e:
                reason = str(e)
            else:
                # 2026-11-23 사용자 결정: 공식 요일·교시가 있으면 운영 방식(온라인 병행·집중이수·
                # 현장실습 등)이 불명확해도 대면으로 보고 그 시각으로 확정한다.
                if p['status']=='currentVerifiedIdentity' and clean(p['sourceSchedule'])!=raw:
                    reason='Current plan/source timetable differ'
                else:
                    status = 'scheduled'
                    parsed = regular_teaching_dates(source_meetings)
        if reason:
            reasons[reason]+=1
            for dep in departments:remarks[dep]+=('\n' if remarks[dep] else '')+'수업 운영·시각 검증 중: 확인 전 자동 반복 추가 불가.'
        course={'sourceId':f'hansung/main/2026/2/{code}/{section}','universityId':'hansung','campus':'main',
                'academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':clean(r['kwamokname']),
                'professor':clean(r['prof']),'credits':float(r['hakjum']),
                'sourceSchedule':raw,'sourceClassroom':raw,'scheduleStatus':status,'schedules':parsed,
                'departments':departments,'departmentCredits':credits,'departmentClassifications':classifications,
                'departmentRemarks':remarks}
        # Calendar explicitly reserves Dec7-19 for final exams/makeup. No guessed exam times.
        if status == 'scheduled':
            course['period'] = {'startDate': '2026-08-31', 'endDate': '2026-12-06'}
        courses.append(course)
    return courses,reasons

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rows', type=Path, required=True)
    parser.add_argument('--proofs', type=Path, required=True)
    parser.add_argument('--review', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    rows = json.loads(args.rows.read_text(encoding='utf-8'))
    proofs = {f.stem: json.loads(f.read_text(encoding='utf-8')) for f in args.proofs.glob('*.json')}
    neutral = set(json.loads(args.review.read_text(encoding='utf-8'))['lines'])
    courses, reasons = prepare(rows, proofs, neutral)
    dataset = {'schemaVersion': 2, 'universityId': 'hansung', 'campus': 'main',
        'campusName': '본교', 'academicYear': 2026, 'semester': '2',
        'publishedDate': '2026-10-24',
        'sourceUrl': 'https://info.hansung.ac.kr/jsp_21/student/kyomu/siganpyo_aui.jsp?viewMode=oc',
        'courses': courses}
    args.output.write_text(json.dumps(dataset, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Whole', len(courses), dict(collections.Counter(c['scheduleStatus'] for c in courses)), dict(reasons))


if __name__ == '__main__':
    main()
