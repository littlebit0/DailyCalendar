#!/usr/bin/env python3
"""Confirm Sunchon (scnu) held courses whose official notation names weekday and periods.

2026-11-23 decision: an official weekday and period is the teaching time even
when the operation mode (remote, field, practicum) is unclear, and a period the
published table omits continues with the same slot length. Dates are built the
way every scheduled scnu course was built (candidate-audit.json): 2026-09-01 to
2026-12-07, minus the listed holidays and midterm week. Courses without a
published time, with another university's name instead of a time, with
contradicting duplicate rows, or whose period table reading splits stay
unrecognized. Re-running changes nothing.

Clock sources:
- day 1-10: 2026-2 수업시간표 (notice nttSn=281319202, HWP section 1 table 3),
  09:00 + 60 min per period, 50-minute class.
- night 11-15 = 야간1-5: same HWP table 4, 18:00 then 50 min per period, 45-minute class.
- night 16 = 야간6 22:10~22:55: 국립순천대학교 교학규정 제52조 평일 표, already used
  for scheduled '요일 야간 4,5,6' courses.

2026-11-23 decision: a section printed in the official timetable stays even when
the 폐강 list names it. --closed-source DIR adds the timetable sections the
importer dropped as closed, built field-for-field like
build_scnu_candidate_20261008.py, then runs the period step above. DIR holds
educational-source-offerings.json (rows read from the notice HWP with
extract_scnu_education_20261008.py logic) and closure.json (the notice's
2026-2학기 폐강 교과목 내역.xlsx rows).

    python3 tool/timetable/apply_scnu_held_periods.py [--closed-source DIR]
"""
import datetime
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/timetable/scnu-unknown-2026-2.json'
DAYS = '월화수목금토일'
CLOCKS = {p: (540 + (p - 1) * 60, 540 + (p - 1) * 60 + 50) for p in range(1, 11)}
CLOCKS.update({p: (1080 + (p - 11) * 50, 1080 + (p - 11) * 50 + 45) for p in range(11, 17)})
SLOT = {p: 60 if p <= 10 else 50 for p in CLOCKS}
FIRST, LAST = datetime.date(2026, 9, 1), datetime.date(2026, 12, 7)
EXCLUDED = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05',
            '2026-10-09', '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22',
            '2026-10-23'}
# Week 1 is the opening week (2026-09-01); the midterm 10/19~23 is then week 8.
WEEK1_MONDAY = datetime.date(2026, 8, 31)
UNKNOWN_ROOMS = {'', '미정', '미배정 강의실', '미배정강의실', '추후지정'}
# Notation the generic reader cannot split; each reading matches the published
# 이론+실습 hours (화,12 -> 화1,2 gives 4 hours for 3/2/2; 화12 would give 3).
OVERRIDES = {'화,12/목8,9': [('화', [1, 2]), ('목', [8, 9])]}
# 토11,12 for a 주간 practicum: 11·12 exist only in the night table, which has no
# Saturday column, and 교학규정 제52조 gives Saturday night a different clock.
AMBIGUOUS = {'scnu-2026-2-ED0043-00'}
TOKEN = re.compile(r'([월화수목금토일])(야간)?([\d,]+)')
WEEKS = re.compile(r'\((\d+)주-(\d+)주\)$')
HOLD_REMARK = re.compile(r' 일정 미생성: [^\n]*$')


def periods_of(text, night):
    out = []
    for piece in filter(None, text.split(',')):
        value = int(piece)
        if night and value < 11:
            value += 10
        if value in CLOCKS:
            out.append(value)
        elif all(int(d) in CLOCKS for d in piece):  # '34' -> 3,4; '야간123' -> 11,12,13
            out.extend(int(d) + (10 if night else 0) for d in piece)
        else:
            raise ValueError(f'unknown period {piece}')
    return out


def parse(source):
    """Return ([(weekday, [periods])], weeks or None, normalized text) or None."""
    text = re.sub(r'\s+', '', source).replace('아간', '야간').replace('.', ',')
    weeks = None
    match = WEEKS.search(text)
    if match:
        weeks = (int(match[1]), int(match[2]))
        text = text[:match.start()]
    if source in OVERRIDES:
        tokens = OVERRIDES[source]
    else:
        if TOKEN.sub('', text).strip(',/'):
            return None
        tokens = [(m[1], periods_of(m[3], m[2] is not None)) for m in TOKEN.finditer(text)]
    if not tokens:
        return None
    meetings = [(DAYS.index(day) + 1, periods) for day, periods in tokens]
    normalized = ''.join(f"{day}{','.join(map(str, p))}" for day, p in tokens)
    return meetings, weeks, normalized


def hours(course):
    education = course['publicEducationRows'][0]['education']
    value = next(v for k, v in education.items() if k.startswith('학/'))
    parts = re.split(r'[/-]', value)
    return int(parts[1]) + int(parts[2]) if len(parts) == 3 and all(
        p.isdigit() for p in parts) and int(parts[2]) <= 10 else None


def schedules(meetings, weeks, room):
    pieces = []
    day = FIRST
    while day <= LAST:
        key = day.isoformat()
        week = (day - WEEK1_MONDAY).days // 7 + 1
        if key not in EXCLUDED and (weeks is None or weeks[0] <= week <= weeks[1]):
            for weekday, periods in meetings:
                if weekday == day.isoweekday():
                    pieces += [[key, weekday, CLOCKS[p][0], CLOCKS[p][0] + SLOT[p]]
                               for p in periods]
        day += datetime.timedelta(days=1)
    pieces.sort(key=lambda p: (p[0], p[2]))
    merged = []
    for piece in pieces:
        if merged and merged[-1][0] == piece[0] and piece[2] - merged[-1][3] < 60:
            merged[-1][3] = max(merged[-1][3], piece[3])
        else:
            merged.append(piece)
    return [{'weekday': w, 'startMinute': s, 'endMinute': e, 'classroom': room, 'date': d}
            for d, w, s, e in merged]


def review(course):
    """Return the confirmed fields for a held course, or None to keep it held."""
    if course['sourceId'] in AMBIGUOUS or course['sourceScheduleAliases'] != [course['sourceSchedule']]:
        return None
    parsed = parse(course['sourceSchedule'])
    if parsed is None:
        return None
    meetings, weeks, normalized = parsed
    count = sum(len(p) for _, p in meetings)
    expected = hours(course)
    if weeks is None and expected is not None and expected != count:
        raise ValueError(f"{course['sourceId']}: {count} periods vs {expected} hours")
    source_room = course['sourceClassroom']
    room = '' if source_room in UNKNOWN_ROOMS or ',' in source_room else source_room
    blocks = [{'weekday': w, 'nativePeriod': p, 'startMinute': CLOCKS[p][0],
               'endMinute': CLOCKS[p][1], 'classroom': source_room}
              for w, periods in meetings for p in periods]
    note = f' 교시 해석: {normalized}'
    if weeks:
        note += f' ({weeks[0]}~{weeks[1]}주, 1주=2026-09-01 개강 주)'
    if any(p == 16 for _, periods in meetings for p in periods):
        note += ', 16교시(22:10~22:55)는 교학규정 제52조 야간 6교시'
    note += '. 운영 방식이 불명확해도 공식 요일·교시로 확정했습니다.'
    return {'schedules': schedules(meetings, weeks, room), 'nativePeriodBlocks': blocks,
            'note': note, 'review': {'interpretedSchedule': normalized,
                                     'weeks': list(weeks) if weeks else None,
                                     'classroom': room}}


def apply(data):
    changed = []
    for course in data['courses']:
        if course['scheduleStatus'] != 'unrecognized':
            continue
        result = review(course)
        if result is None:
            continue
        course['scheduleStatus'] = 'scheduled'
        course['schedules'] = result['schedules']
        course['nativePeriodBlocks'] = result['nativePeriodBlocks']
        course['heldPeriodReview'] = result['review']
        course['remarks'] = HOLD_REMARK.sub('', course['remarks']) + result['note']
        for department, text in course['departmentRemarks'].items():
            course['departmentRemarks'][department] = HOLD_REMARK.sub('', text) + result['note']
        changed.append(course['sourceId'])
    return changed


BASE_REMARK = ('2026-08-24 10:00 학교 공개 수업시간표의 정규 수업 계획입니다. 실제 출석·개별 휴강 확정이 아니며 '
               '실시간 시스템 변경 전체는 확인되지 않았습니다. 10/19~23 중간시험, 12/8~11 국·공휴일 보강, '
               '12/14~18 기말시험은 강좌별 시각·강의실 미확인으로 일정에 포함하지 않았습니다. 개별 강좌 캠퍼스 '
               '미공개이며 대학 전체 자료 범위입니다. ')
CLOSED_LISTED = ' 공식 수업시간표에 게시, 폐강 목록에도 있음.'
CLOSED_EARLIER = ' 공식 수업시간표에 게시, 2026-10-08 조회 폐강 목록에 있었음(2026-11-23 공지 첨부 폐강 내역에는 없음).'
TOKEN_BUILD = re.compile(r'([월화수목금토일])(야간)?(\d+(?:,\d+)*)')


def closed_course(code, section, src, note):
    """A closed section rebuilt like build_scnu_candidate_20261008.py builds every other row."""
    fields = {k: sorted({r['education'].get(k, '') for r in src}) for k in ['교과목명', '강의시간', '강의실', '담당교수']}
    conflicts = {k: v for k, v in fields.items() if len({re.sub(r'\s+', '', x) for x in v}) > 1}
    e = src[0]['education']; tm = e.get('강의시간', ''); room = e.get('강의실', ''); reasons = []; blocks = []
    if conflicts: reasons.append('native code/section duplicate conflicts: ' + ','.join(conflicts))
    compact = re.sub(r'\s+', '', tm).replace('/', '')
    matches = list(TOKEN_BUILD.finditer(compact)); remainder = TOKEN_BUILD.sub('', compact)
    if remainder: reasons.append('native notation not fully resolved: ' + remainder)
    if not matches: reasons.append('no published fixed weekday/period')
    for m in matches:
        periods = [int(x) for x in m[3].split(',')]
        if m[2] and any(p < 11 for p in periods): periods = [p + 10 for p in periods]
        for p in periods:
            if p not in CLOCKS or p == 16:
                reasons.append('published period clock absent: ' + str(p)); continue
            blocks.append({'weekday': DAYS.index(m[1]) + 1, 'nativePeriod': p, 'startMinute': CLOCKS[p][0],
                           'endMinute': CLOCKS[p][1], 'classroom': room})
    if not room or re.search('미정|미배정|추후|협의', room): reasons.append('published classroom absent/unconfirmed')
    if not re.fullmatch(r'(?:[A-E]\d{5}|\d{3})', room): reasons.append('room notation needs meeting-specific interpretation')
    if re.search(r'집중|블렌디드|비대면|온라인|원격|현장|주-?\d|주차', e.get('교과목명', '') + ' ' + tm):
        reasons.append('special/field/remote/week-limited operation dates or mode unresolved')
    if any('별도 학사관리시스템' in str(r['sourceContext']) for r in src): reasons.append('source says external remote operation')
    categories = sorted({r['education'].get('이수구분', r['education'].get('영역', '')) for r in src} - {''})
    contexts = list(dict.fromkeys(v for r in src for v in r['sourceContext']))
    deps = sorted({r['education'].get('협력학과', r['education'].get('담당학과', r['education'].get('수강대상학과', ''))) for r in src} - {''})
    deps += list(dict.fromkeys(r['sourceContext'][0] for r in src if r['sourceTable'] >= 48 and r['sourceContext']))
    deps = list(dict.fromkeys(deps)); cat = categories[0] if len(categories) == 1 else ''
    if not cat and src[0]['sourceTable'] < 37: cat = next((x for x in contexts if '교양' in x), '')
    group = '전공' if any(x.startswith('전공') for x in categories) else '교직' if any('교직' in x or '교육실습' == x for x in categories) else '교양' if src[0]['sourceTable'] < 37 or '교양' in cat else ''
    units = sorted({next((v for k, v in r['education'].items() if k.startswith('학/이/실')), '') for r in src})
    credits = None
    if len(units) == 1 and (m := re.match(r'(\d+(?:\.\d+)?)', units[0])): credits = float(m[1])
    remarks = BASE_REMARK + '원문 수강조건: ' + '; '.join(contexts) + '; ' + '; '.join(
        k + ': ' + v for k, v in e.items() if k in {'수강대상', '대상학년', '학년', '인원제한', '사범대학이수시기', '교직과정이수시기', '수강대상학과'} and v)
    remarks += note
    schedules_ = []
    if not reasons:
        meetings, weeks, _ = parse(tm)
        schedules_ = schedules(meetings, weeks, room)
    else:
        remarks += ' 일정 미생성: ' + '; '.join(dict.fromkeys(reasons))
    return {'sourceId': f'scnu-2026-2-{code}-{section}', 'referenceKind': '교과목코드', 'canonicalSubjectCodePublished': True,
            'nativeSectionPublished': True, 'campus': 'unknown',
            'campusEvidence': 'No per-offering campus field published; institution scope only. Room codes retained without deriving physical campus.',
            'academicYear': 2026, 'semester': '2', 'courseCode': code, 'courseName': e['교과목명'], 'section': section,
            'professor': e.get('담당교수', '') if '담당교수' not in conflicts else '', 'credits': credits,
            'classification': cat, 'sourceClassificationAliases': categories, 'classificationGroup': group,
            'departments': deps, 'departmentCredits': {d: credits for d in deps} if credits is not None else {},
            'departmentClassifications': {}, 'departmentRemarks': {d: remarks for d in deps}, 'remarks': remarks,
            'sourceSchedule': tm, 'sourceClassroom': room, 'sourceScheduleAliases': fields['강의시간'],
            'sourceClassroomAliases': fields['강의실'], 'scheduleStatus': 'scheduled' if schedules_ else 'unrecognized',
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-18'}, 'schedules': schedules_,
            'nativePeriodBlocks': blocks, 'publicEducationRows': src}


def add_closed(data, rows, closure_items):
    """Add timetable sections the importer dropped as closed. Returns added sourceIds."""
    by = {}
    for r in rows:
        e = r['education']; by.setdefault((e.get('코드', e.get('교과목코드')), e['분반']), []).append(r)
    present = {(c['courseCode'], c['section']) for c in data['courses']}
    listed = {(i['H'], i['J']) for i in closure_items if i.get('K') == '폐강'}
    added = []
    for (code, section), src in sorted(by.items()):
        if (code, section) in present:
            continue
        note = CLOSED_LISTED if (code, section) in listed else CLOSED_EARLIER
        data['courses'].append(closed_course(code, section, src, note))
        added.append(f'scnu-2026-2-{code}-{section}')
    return added


def main():
    import argparse
    parser = argparse.ArgumentParser()
    # Folder with educational-source-offerings.json (HWP rows) and closure.json (폐강 xlsx rows).
    parser.add_argument('--closed-source', type=Path)
    args = parser.parse_args()
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    added = []
    if args.closed_source:
        rows = json.loads((args.closed_source / 'educational-source-offerings.json').read_text(encoding='utf-8'))
        sheet = json.loads((args.closed_source / 'closure.json').read_text(encoding='utf-8'))
        items = [r['cells'] for v in sheet.values() for r in v if r['row'] >= 5]
        added = add_closed(data, rows, items)
        print('closed sections added', len(added))
    changed = apply(data)
    if changed or added:
        ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                         encoding='utf-8')
    print('confirmed', len(changed))


if __name__ == '__main__':
    main()
