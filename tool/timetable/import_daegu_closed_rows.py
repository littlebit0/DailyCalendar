#!/usr/bin/env python3
"""Add the Daegu rows earlier builds dropped because the closure list named them.

2026-11-23 user decision: a course printed in the official comprehensive
timetable PDF is added even when a closure notice names it; closure is not
judged and the row follows the same rules as every other course.

Every table kind (전공, 교양·교직/자유선택/일선/연계전공, 마이크로전공 and the
창의융복합전공 sub-tables) is rebuilt from daegu_pdf_columns.swift strips cut at
that kind's printed header columns. The rebuild must reproduce every
publicEducationRows[].education field already in the asset (whitespace
ignored) before anything is written. Only registration numbers absent from the
asset are added; existing course records are never changed.

Schedule rules match the 2026-11-23 asset (commit f42b5c875): a printed
'요일(HH:MM-HH:MM)' clock is confirmed even when the operation mode is unclear;
rows of one number that print the same room short and long use the long form;
an empty clock with a DU-MOOC/K-MOOC/본교가상/외부가상 room is unscheduled;
no clock, differing clocks or differing rooms stay unrecognized.
No networking; standard library only.
"""
import argparse
import collections
import datetime
import importlib.util
import json
import re
from pathlib import Path

_spec = importlib.util.spec_from_file_location('import_daegu_missing_rows', Path(__file__).with_name('import_daegu_missing_rows.py'))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)
clean, CLOCK, HOLIDAYS, REMARK = base.clean, base.CLOCK, base.HOLIDAYS, base.REMARK

GENERAL_TITLES = ('교양·교직 강의시간표', '자유선택 강의시간표', '일선 강의시간표', '연계전공 강의시간표')
MICRO_TITLE = '마이크로전공 강의시간표'
GENERAL = ['구분', '학년', '수강학과', '수강번호', '교과목명', '학점', '시간', '담당교수', '강의시간', '강의실', '소영역', '비고']
MICRO = ['구분', '학년', '수강학과', '수강번호', '교과목명', '학점', '시간', '담당교수', '강의시간', '강의실', '비고']
CONVERGENCE = ['학년', '구분', '수강학과', '수강번호', '교과목명', '학점', '시간', '담당교수', '강의시간', '강의실', '비고']
# x edges of each kind's printed columns (PDF points), passed to daegu_pdf_columns.swift.
EDGES = {
    'general': '40,85,103,150,176,258,270,299,341,412,464,508,560',
    'micro': '40,85,103,150,176,286,300,328,370,441,492,560',
    'convergence': '40,72,98,150,176,272,288,323,371,438,495,560',
    'major': '40,72,98,150,176,272,288,323,371,438,495,522,560',
}
VIRTUAL_ROOMS = {'DU∼MOOC', 'K∼MOOC', '본교가상', '외부가상'}
SPECIAL = re.compile('집중|블렌디드|가상|MOOC|원격|실습기간|Flex')
MARK = ' 공식 시각 확정(2026-11-23)'
CLOSURE_NOTE = ' / 2026-11-23 사용자 결정: 폐강 공지 대상이어도 공식 시간표 행이므로 다른 강좌와 같은 규칙으로 넣음.'
CLOCK_NOTE = (' / 2026-11-23 사용자 결정: 공식 요일·시각이 있으면 운영 방식(블렌디드·집중·MOOC·원격 등)이 '
              '불명확해도 대면 수업으로 보고 그 시각으로 확정합니다.')
LONG_ROOM_NOTE = (' / 2026-11-23 확인: 같은 수강번호의 공식 PDF 행들이 같은 강의실을 짧은 표기(예: 사회3관-32)와 '
                  '긴 표기(예: 사회3관-3202)로 적었습니다. 긴 표기로 통일했습니다.')
VIRTUAL_NOTE = (' / 2026-11-23 확인: 강의시간이 비어 있고 강의실이 DU-MOOC·본교가상·외부가상(온라인 강좌)이므로 '
                '요일·시각이 없는 강좌로 둡니다.')


def subtitle(whole):
    return [clean(l[0]) for l in sorted(whole, key=lambda l: l[2]) if 80 < l[2] < 100][:1]


def general_title(whole):
    found = [t for t in GENERAL_TITLES if any(l[0].strip() == t for l in whole)]
    return found[:1] + subtitle(whole) if found else None


def micro_title(whole):
    return [MICRO_TITLE] + subtitle(whole) if any(l[0].strip() == MICRO_TITLE for l in whole) else None


def convergence_title(whole):
    # 창의융복합전공 pages print no 강의시간표 title, only the programme name above the header.
    if any(l[0].strip() in GENERAL_TITLES + (MICRO_TITLE, base.MAJOR_TITLE) for l in whole):
        return None
    if not any(l[0].strip() == '수강학과' for l in whole):
        return None
    return [clean(l[0]) for l in sorted(whole, key=lambda l: l[2]) if 95 < l[2] < 115 and l[1] < 50][:1]


def extract_all(lines, kinds):
    """kinds: {'general'|'micro'|'convergence'|'major': strip dump}; returns all rebuilt rows."""
    spec = {'general': (GENERAL, general_title), 'micro': (MICRO, micro_title),
            'convergence': (CONVERGENCE, convergence_title), 'major': (base.NAMES, base.major_title)}
    rows = []
    for kind, cols in kinds.items():
        names, title_of = spec[kind]
        rows += base.extract_rows(lines, cols, names, title_of)
    return rows


def z(value):
    return re.sub(r'\s+', '', value or '')


def choose_room(rooms):
    """One printed room for the course, or None when rows print different rooms."""
    distinct = sorted({clean(r) for r in rooms}, key=len)
    if len(distinct) <= 1:
        return (distinct or [''])[0], False
    longest = distinct[-1]
    # The PDF clips long room names; a short form is a prefix of the full one.
    if all(z(longest).startswith(z(r)) and z(r) for r in distinct):
        return longest, True
    return None, False


def build_course(code, src):
    first = src[0]['education']
    fields = {k: sorted({x['education'].get(k, '') for x in src}) for k in ['교과목명', '강의시간', '강의실', '담당교수', '학점', '구분']}
    conflicts = {k for k, v in fields.items() if len({z(x) for x in v}) > 1 and k != '구분'}
    cats = [x for x in fields['구분'] if x]
    source, room0 = first.get('강의시간', ''), first.get('강의실', '')
    blocks = []
    for m in CLOCK.finditer(source):
        a, b = int(m[2]) * 60 + int(m[3]), int(m[4]) * 60 + int(m[5])
        assert 0 <= a < b <= 1440
        blocks.append({'weekday': '월화수목금토일'.index(m[1]) + 1, 'startMinute': a, 'endMinute': b, 'classroom': room0})
    room, long_room = choose_room(fields['강의실'])
    reasons, notes = [], []
    if '강의시간' in conflicts:
        reasons.append('published duplicate native reference has conflicting 강의시간')
    if room is None:
        reasons.append('published duplicate native reference has conflicting 강의실')
    remainder = CLOCK.sub('', source).strip(' ,/')
    if remainder:
        reasons.append('native weekly clock notation unrecognized: ' + remainder)
    if not blocks:
        reasons.append('source publishes no fixed weekly clock')
    if blocks and not room:
        reasons.append('source classroom absent')
    status = 'unrecognized'
    if not source.strip() and all(z(x['education'].get('강의실')) in VIRTUAL_ROOMS for x in src):
        status, reasons = 'unscheduled', []
        notes.append(VIRTUAL_NOTE)
    elif not reasons:
        status = 'scheduled'
        if any(SPECIAL.search(str(x['education'])) for x in src):
            notes.append(CLOCK_NOTE)
        if long_room:
            notes.append(LONG_ROOM_NOTE)
    notes.append(CLOSURE_NOTE)
    meetings = []
    if status == 'scheduled':
        for i in range(98):
            d = datetime.date(2026, 9, 1) + datetime.timedelta(days=i)
            if str(d) in HOLIDAYS:
                continue
            meetings += [{**b, 'classroom': room, 'date': str(d)} for b in blocks if b['weekday'] == d.isoweekday()]
    depts = sorted({x['education'].get('수강학과', '') for x in src} - {''})
    depcredit, depclass, depremarks = {}, {}, {}
    for dept in depts:
        rows = [x['education'] for x in src if x['education'].get('수강학과') == dept]
        cr = {x.get('학점', '') for x in rows}
        cl = {x.get('구분', '') for x in rows} - {''}
        if len(cr) == 1:
            try:
                depcredit[dept] = float(next(iter(cr)))
            except ValueError:
                pass
        if len(cl) == 1:
            depclass[dept] = next(iter(cl))
        depremarks[dept] = '수강학과 원문: ' + dept + '; ' + '; '.join(sorted({x.get('비고', '') for x in rows} - {''}))
    remark = REMARK + (MARK if status == 'scheduled' else '')
    if reasons:
        remark += ' 일정 미생성: ' + '; '.join(reasons)
    remark += ' 수강 대상: ' + ', '.join(depts) + '; 원문 비고: ' + '; '.join(sorted({x['education'].get('비고', '') for x in src} - {''}))
    tail = ''.join(notes)
    try:
        credits = float(fields['학점'][0]) if len(fields['학점']) == 1 else None
    except ValueError:
        credits = None
    return {'sourceId': 'daegu-2026-2-registration-' + code, 'referenceKind': '수강번호', 'canonicalSubjectCodePublished': False,
            'nativeSectionPublished': False, 'campus': 'main',
            'campusEvidence': 'academyinfo:0000084 본교 institution scope; comprehensive timetable has no per-offering campus selector, no inferred room location',
            'academicYear': 2026, 'semester': '2', 'courseCode': code, 'courseName': first['교과목명'], 'courseNameAliases': fields['교과목명'],
            'section': '', 'professor': first.get('담당교수', '') if '담당교수' not in conflicts else '', 'credits': credits,
            'classification': cats[0] if len(cats) == 1 else '', 'sourceClassificationAliases': cats, 'departments': depts,
            'departmentCredits': depcredit, 'departmentClassifications': depclass,
            'departmentRemarks': {k: remark + '\n' + v + tail for k, v in depremarks.items()},
            'remarks': remark + tail, 'sourceSchedule': source, 'sourceClassroom': room0, 'sourceScheduleAliases': fields['강의시간'],
            'sourceClassroomAliases': fields['강의실'], 'scheduleStatus': status,
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-14'}, 'schedules': meetings, 'sourceSnapshotSchedules': blocks,
            'publicEducationRows': src,
            'datesMeaning': 'published ordinary regular teaching through December7, without autonomous makeups or exams; attendance unconfirmed'}


def self_check(rows, courses):
    """Every education field already in the asset must be rebuilt (whitespace ignored)."""
    index = collections.defaultdict(list)
    for r in rows:
        index[(r['sourcePage'], r['nativeRegistrationNumber'])].append(r['education'])
    compared, failures = 0, []
    for c in courses:
        for old in c['publicEducationRows']:
            key = (old['sourcePage'], old['nativeRegistrationNumber'])
            want = {k: z(v) for k, v in old['education'].items()}
            if any(all(z(e.get(k)) == v for k, v in want.items()) for e in index.get(key, [])):
                compared += 1
            else:
                failures.append({'key': key, 'asset': old['education'], 'rebuilt': index.get(key, [])})
    return compared, failures


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--lines', required=True, help='daegu_pdf_columns.swift output with edges 0,600')
    for kind in EDGES:
        p.add_argument('--' + kind, required=True, help=f'daegu_pdf_columns.swift output with edges {EDGES[kind]}')
    p.add_argument('--asset', required=True)
    p.add_argument('--report', required=True)
    a = p.parse_args()
    load = lambda f: json.loads(Path(f).read_text(encoding='utf-8'))
    lines = {x['page']: x['lines'] for x in load(a.lines)}
    rows = extract_all(lines, {k: {x['page']: x['lines'] for x in load(getattr(a, k))} for k in EDGES})
    asset = load(a.asset)
    compared, failures = self_check(rows, asset['courses'])
    if failures:
        Path(a.report).write_text(json.dumps({'selfCheckFailures': failures}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        raise SystemExit(f'{len(failures)} asset rows not rebuilt; asset not written (see {a.report})')
    existing = {c['courseCode'] for c in asset['courses']}
    by = collections.defaultdict(list)
    for r in rows:
        if r['nativeRegistrationNumber'] not in existing:
            r['extraction'] = 'official PDF text positions by column strip (PDFKit)'
            by[r['nativeRegistrationNumber']].append(r)
    for src in by.values():
        src.sort(key=lambda r: (r['sourcePage'], r['tableIndex'], r['sourceRow']))
        assert all(r['education']['교과목명'] for r in src), src[0]
    before = json.dumps(sorted(asset['courses'], key=lambda c: c['courseCode']), ensure_ascii=False, sort_keys=True)
    new = [build_course(code, src) for code, src in sorted(by.items())]
    asset['courses'] = sorted(asset['courses'] + new, key=lambda c: c['courseCode'])
    kept = [c for c in asset['courses'] if c['courseCode'] in existing]
    assert json.dumps(kept, ensure_ascii=False, sort_keys=True) == before, 'existing course changed'
    Path(a.asset).write_text(json.dumps(asset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    kinds = collections.Counter()
    for src in by.values():
        kinds[' + '.join(sorted({r['sourceTitleLines'][0] if r['sourceTitleLines'][0].endswith('강의시간표') else '창의융복합전공'
                                 for r in src}))] += 1
    report = {'rebuiltRows': len(rows), 'assetRowsReproduced': compared, 'fieldDifferences': 0,
              'addedCourses': len(new), 'addedByTable': dict(kinds),
              'addedStatus': dict(collections.Counter(c['scheduleStatus'] for c in new)),
              'addedMeetings': sum(len(c['schedules']) for c in new), 'totalCourses': len(asset['courses']),
              'added': {c['courseCode']: [c['courseName'], c['scheduleStatus'], c['sourceSchedule'], c['sourceClassroomAliases']] for c in new}}
    Path(a.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'added'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
