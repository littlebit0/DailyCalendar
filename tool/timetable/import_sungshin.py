#!/usr/bin/env python3
"""Build Sungshin 2026-2 undergraduate datasets from fetch_sungshin.py output.

Sources (all fetched 2026-10-23):
- Rows: 개설강좌조회 (https://sugang.sungshin.ac.kr/findBCRM02010.do), 2026 2학기,
  조직분류 '대학'. mng_*.json (과목구분 5개) and obj_*.json (대상과정 11개) are two
  independent partitions; both must give the same offerings.
- Clock: 강의시간편성표 https://sugang.sungshin.ac.kr/html/timeRef.htm,
  "1교시 (09:00~09:50)" … "12교시 (20:00~20:50)".
- Dates: 학사운영팀 2026-2학기 수강신청 안내(학부) p5 요일별 수업일 표
  (https://www.sungshin.ac.kr/bbs/main_kor/3181/157409/artclView.do):
  "모든 학부 수업(대면, 비대면, 혼합형 수업)은 상기 요일별 수업일을 기준으로 진행합니다."
  15주차 금요일 수업일은 12월 22일(화) (요일변경).

Held as `unrecognized` (never guessed):
- 원격(녹화콘텐츠)·원격(블렌디드형)·일반(블렌디드형) rows with a published slot: the
  guide p8 marks them 원격/혼합형, so whether the slot is a class meeting is the
  user's call.
- 8주(집중) rows, unless the syllabus lists every session date and each date
  falls on a published weekday.
- Schedule text outside the published grammar.
"""
import argparse
import datetime as dt
import html
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
# 강의시간편성표: n교시 = 09:00 + (n-1)h, 50분 수업 + 10분 쉬는 시간.
# 쉬는 시간을 각 교시에 포함한 60분 슬롯으로 기록한다(종료 = 시작 + 60).
CLOCK = {p: (480 + p * 60, 540 + p * 60) for p in range(1, 13)}
# 2026-2 수강신청 안내 p5, 요일별 1~15주차 수업일.
TEACHING_DATES = {
    1: '09-07 09-14 09-21 09-28 10-12 10-19 10-26 11-02 11-09 11-16 11-23 11-30 12-07 12-14 12-21',
    2: '09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-03 11-10 11-17 11-24 12-01 12-08',
    3: '09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-21 10-28 11-04 11-11 11-18 11-25 12-02 12-09',
    4: '09-03 09-10 09-17 10-01 10-08 10-15 10-22 10-29 11-05 11-12 11-19 11-26 12-03 12-10 12-17',
    5: '09-04 09-11 09-18 10-02 10-16 10-23 10-30 11-06 11-13 11-20 11-27 12-04 12-11 12-18 12-22',
    6: '09-05 09-12 09-19 09-26 10-03 10-10 10-17 10-24 10-31 11-07 11-14 11-21 11-28 12-05 12-12',
}
TEACHING_DATES = {d: [dt.date.fromisoformat('2026-' + x) for x in v.split()]
                  for d, v in TEACHING_DATES.items()}
BLOCK = re.compile(r'([월화수목금토일])/(\d{1,2})(?:-(\d{1,2}))?')
CAMPUS = {'수정': ('sujeong', '돈암수정캠퍼스'), '운정': ('unjung', '미아운정그린캠퍼스')}
HELD_TYPES = {'원격(녹화콘텐츠)', '원격(블렌디드형)', '일반(블렌디드형)'}
ADMISSION_NOTE = ('10/16(금)·10/17(토)는 입학전형(준비)로 대면수업이 불가능할 수 있음'
                  '(2026-2 수강신청 안내 p5)')


def clean(value):
    return re.sub(r'\s+', ' ', str(value or '')).strip()


def blocks(text):
    parts = [p.strip() for p in text.split(',')]
    result = []
    for part in parts:
        m = BLOCK.fullmatch(part)
        if not m:
            return None
        first, last = int(m[2]), int(m[3] or m[2])
        if first not in CLOCK or last not in CLOCK or last < first:
            return None
        result.append((DAYS.index(m[1]) + 1, CLOCK[first][0], CLOCK[last][1]))
    return result


def rooms_for(text, count):
    rooms = [r.strip() for r in text.split(',')] if text else []
    if len(rooms) == count:
        return rooms
    if count == 1:
        return [text]
    if len(rooms) == 1:
        return rooms * count  # One published room for the whole offering.
    return [''] * count


def syllabus_dates(path):
    """Session dates written in the syllabus weekly table, or None."""
    if not path.exists():
        return None
    text = html.unescape(re.sub(r'<[^>]+>', ' ', path.read_text()))
    dates = re.findall(r'\d+주\s*\d+회차\s*\((\d{2})/(\d{2})\)', text)
    sessions = re.findall(r'\d+주\s*\d+회차', text)
    if not dates or len(dates) != len(sessions):
        return None
    return [dt.date(2026, int(m), int(d)) for m, d in dates]


def meetings_for(parsed, rooms, dates_by_weekday):
    result = []
    for (weekday, start, end), room in zip(parsed, rooms):
        for date in dates_by_weekday[weekday]:
            result.append({'date': date.isoformat(), 'weekday': date.isoweekday(),
                           'startMinute': start, 'endMinute': end, 'classroom': room})
    result.sort(key=lambda m: (m['date'], m['startMinute'], m['endMinute']))
    # 같은 날 이어지는 교시(사이가 한 교시 미만)는 한 구간으로 합친다.
    merged = []
    for meeting in result:
        last = merged[-1] if merged else None
        if last and last['date'] == meeting['date'] and meeting['startMinute'] - last['endMinute'] < 60:
            last['endMinute'] = max(last['endMinute'], meeting['endMinute'])
        else:
            merged.append(meeting)
    return merged


def schedule(row, raw_dir):
    text = clean(row.get('tmtblKorDsc'))
    if not text:
        return 'unscheduled', [], ''
    parsed = blocks(text)
    if parsed is None:
        return 'unrecognized', [], '시간표 표기 해석 불가'
    if clean(row.get('lesnTypNm')) in HELD_TYPES:
        return 'unrecognized', [], '수업유형 ' + clean(row['lesnTypNm'])
    rooms = rooms_for(clean(row.get('roomKorDsc')), len(parsed))
    dates = TEACHING_DATES
    if clean(row.get('atntLesnNm')):
        listed = syllabus_dates(raw_dir / f"plan_{row['sbjNo']}_{row['dvcls']}.html")
        weekdays = {w for w, _, _ in parsed}
        if not listed or any(d.isoweekday() not in weekdays for d in listed):
            return 'unrecognized', [], '집중이수 수업일 미공개'
        dates = {w: [d for d in listed if d.isoweekday() == w] for w in weekdays}
    elif any(w == 7 for w, _, _ in parsed):
        return 'unrecognized', [], '일요일 수업일 미공개'
    return 'scheduled', meetings_for(parsed, rooms, dates), ''


def course(row, raw_dir):
    campus = CAMPUS[clean(row['cmpCdNm'])][0]
    number, section = clean(row['sbjNo']), clean(row['dvcls'])
    title, department = clean(row['sbjNm']), clean(row['opDptmjrNm'])
    credits = float(clean(row['cdtHcnt']).split('/')[0])
    if not title or not number or not department or not 0 <= credits <= 30:
        raise ValueError(f'Invalid Sungshin course {number}-{section}')
    status, meetings, held = schedule(row, raw_dir)
    area = clean(row.get('sbjAreaNm'))
    remarks = [
        clean(row.get('rmkDsc')),
        '수강대상: ' + clean(row['objrAsgnDsc']) if clean(row.get('objrAsgnDsc')) else '',
        '수업유형: ' + clean(row['lesnTypNm']) if clean(row.get('lesnTypNm')) not in ('', '일반') else '',
        '집중이수: ' + clean(row['atntLesnNm']) if clean(row.get('atntLesnNm')) else '',
        '강의언어: ' + clean(row['lesnLangNm']) if clean(row.get('lesnLangNm')) not in ('', '한국어') else '',
        '영역: ' + area if area not in ('', '영역없음') else '',
        '교과목특성: ' + clean(row['sbjCharNm']) if clean(row.get('sbjCharNm')) else '',
        '학점/이론/실습 ' + clean(row['cdtHcnt']),
        ADMISSION_NOTE if any(m['date'] in ('2026-10-16', '2026-10-17') for m in meetings) else '',
        '시각 보류: ' + held if held else '',
    ]
    remark = ' · '.join(dict.fromkeys(r for r in remarks if r))
    return {
        'sourceId': f'sungshin/{campus}/2026/2/{number}-{section}',
        'universityId': 'sungshin', 'campus': campus, 'academicYear': 2026,
        'semester': '2', 'courseCode': number, 'section': section,
        'courseName': title, 'professor': clean(row.get('profDsc')),
        'credits': credits, 'sourceSchedule': clean(row.get('tmtblKorDsc')),
        'sourceClassroom': clean(row.get('roomKorDsc')),
        'scheduleStatus': status, 'schedules': meetings,
        'departments': [department],
        'departmentCredits': {department: credits},
        'departmentClassifications': {department: clean(row['cpdivNm'])},
        'departmentRemarks': {department: remark},
    }


def load_rows(raw_dir):
    key = lambda r: (r['orgClsfCd'], r['dptMjrCd'], r['sbjNo'], r['dvcls'])
    by_category = {}
    for path in sorted(raw_dir.glob('mng_*.json')):
        for row in json.loads(path.read_text()):
            if row['orgClsfCd'] == 'COMM075.101':
                by_category[key(row)] = row
    by_course = {key(r): r for r in json.loads((raw_dir / 'obj_10.json').read_text())}
    if set(by_category) != set(by_course) or any(r['orgClsfCd'] != 'COMM075.101' for r in by_course.values()):
        raise ValueError('Partitions disagree; collection incomplete')
    return [by_course[k] for k in sorted(by_course)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--checked-at', required=True)
    args = parser.parse_args()
    rows = load_rows(args.raw)
    for label, (campus, name) in CAMPUS.items():
        courses = sorted((course(r, args.raw) for r in rows if clean(r['cmpCdNm']) == label),
                         key=lambda c: c['sourceId'])
        document = {
            # Dated meetings require schema 2.
            'schemaVersion': 2, 'universityId': 'sungshin', 'campus': campus,
            'campusName': name, 'academicYear': 2026, 'semester': '2',
            'publishedDate': args.checked_at,
            'sourceUrl': 'https://sugang.sungshin.ac.kr/findBCRM02010.do',
            'courses': courses,
        }
        path = args.output / f'sungshin-{campus}-2026-2.json'
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
        counts, held = {}, {}
        for c in courses:
            counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
            reason = re.search(r'시각 보류: ([^·]+)', c['departmentRemarks'][c['departments'][0]])
            if reason:
                held[reason[1].strip()] = held.get(reason[1].strip(), 0) + 1
        print(campus, len(courses), counts, held)


if __name__ == '__main__':
    main()
