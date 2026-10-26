#!/usr/bin/env python3
"""Add 전공 강의시간표 rows the 2026-10-08 Daegu extraction missed.

The earlier table extractor skipped pages whose table had no header row and
header-less continuation rows at the top of a page. This script rebuilds every
전공 강의시간표 row from the official PDF text positions dumped by
daegu_pdf_columns.swift, proves the rebuild equals every previously extracted
row, and appends only registration numbers that were absent before.

Existing course records are never changed. New records follow the same rules as
the original candidate build (closures removed, special/remote/blended and
conflicting rows held, only directly printed weekday clocks projected).
No networking; standard library only.
"""
import argparse
import collections
import datetime
import json
import re
from pathlib import Path

MAJOR_TITLE = '전공 강의시간표'
NAMES = ['학년', '구분', '수강학과', '수강번호', '교과목명', '학점', '시간', '담당교수', '강의시간', '강의실', '비고', '']
END = re.compile(r'^(※|1\. 교차설강|\* 강의담당|2\. 강의실|지정된 교과목)')
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
CLOCK = re.compile(r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)')
REMARK = ('학교 공개 수업시간표의 수강번호입니다. 별도 교과목코드 및 분반은 공개되지 않았습니다. '
          '공개 정규 수업 계획이며 실제 출석·개별 휴강 확정이 아닙니다. '
          '휴일 자율보강 및 12/8~12/14 기말 운영은 강좌별 확인이 필요하여 일정에 포함하지 않았습니다. '
          'TIGERS 실시간 변경 전체는 검증되지 않았습니다.')


def clean(value):
    return re.sub(r'\s+', ' ', value).strip()


def extract_major_rows(lines, cols):
    rows = []
    for page in sorted(cols):
        whole = lines[page]
        if not any(l[0].strip() == MAJOR_TITLE for l in whole):
            continue
        title = [clean(l[0]) for l in sorted(whole, key=lambda l: l[2]) if 80 < l[2] < 100]
        headers = [l[2] for l in whole if l[0].strip().startswith('교과목명')]
        ends = [l[2] for l in whole if END.match(l[0].strip())]
        segs = sorted((s for s in cols[page] if s[0].strip()), key=lambda s: (s[2], s[1]))
        anchors = [s for s in segs if s[5] == 3 and re.fullmatch(r'\d{4}', s[0].strip())]
        table, ordinal, last = 0, 0, {}
        for i, anchor in enumerate(anchors):
            top = anchor[2]
            bottom = min([b[2] for b in anchors[i + 1:i + 2]] + [y for y in ends + headers if y > top] + [9999])
            if i and any(anchors[i - 1][2] < y < top for y in headers + ends):
                table, ordinal, last = table + 1, 0, {}
            ordinal += 1
            cells = collections.defaultdict(list)
            for s in segs:
                if top - 1 <= s[2] < bottom - 1:
                    cells[s[5]].append(s[0].strip())
            raw = ['\n'.join(cells.get(k, [])) for k in range(len(NAMES))]
            education = {NAMES[k]: clean(raw[k]) for k in range(len(NAMES))}
            # Merged 학년/구분 cells carry down only inside the same printed table.
            for field in ['학년', '구분']:
                if education[field]:
                    last[field] = education[field]
                elif field in last:
                    education[field] = last[field]
            rows.append({'sourcePage': page, 'tableIndex': table, 'sourceRow': ordinal,
                         'sourceTitleLines': ['전공 강의시간표'] + title[:1],
                         'nativeRegistrationNumber': education['수강번호'], 'nativeSection': '',
                         'nativeCanonicalCourseCodePublished': False, 'education': education,
                         'sourceCells': raw, 'extraction': 'official PDF text positions by column strip (PDFKit)'})
    return rows


def build_course(code, src, special):
    e = src[0]['education']
    fields = {k: sorted({x['education'].get(k, '') for x in src}) for k in ['교과목명', '강의시간', '강의실', '담당교수', '학점', '구분']}
    conflicts = {k: v for k, v in fields.items() if len({re.sub(r'\s+', '', x) for x in v}) > 1 and k != '구분'}
    cats = [x for x in fields['구분'] if x]
    cat = cats[0] if len(cats) == 1 else ''
    reasons = []
    if conflicts:
        reasons.append('published duplicate native reference has conflicting ' + ','.join(conflicts))
    if code in special or any(re.search('집중|블렌디드|가상|MOOC|원격|실습기간', str(x['education'])) for x in src):
        reasons.append('special/remote/blended operation dates or mode unresolved; native snapshot clock is not assumed actual teaching')
    if any(re.search('친족상속법|가족법', x['education']['교과목명']) for x in src):
        reasons.append('September3 room change is published by course title; native reference join not established')
    source, room, blocks = e.get('강의시간', ''), e.get('강의실', ''), []
    for m in CLOCK.finditer(source):
        a, b = int(m[2]) * 60 + int(m[3]), int(m[4]) * 60 + int(m[5])
        assert 0 <= a < b <= 1440
        blocks.append({'weekday': '월화수목금토일'.index(m[1]) + 1, 'startMinute': a, 'endMinute': b, 'classroom': room})
    remainder = CLOCK.sub('', source).strip(' ,/')
    if remainder:
        reasons.append('native weekly clock notation unrecognized: ' + remainder)
    if not blocks:
        reasons.append('source publishes no fixed weekly clock')
    if not room:
        reasons.append('source classroom absent')
    if any('\n' in x['sourceCells'][NAMES.index('강의실')] for x in src) or any(ch in room for ch in [',', '/']):
        reasons.append('room contains multiple lines/places without meeting-specific mapping')
    meetings = []
    if not reasons:
        for i in range(98):
            d = datetime.date(2026, 9, 1) + datetime.timedelta(days=i)
            if str(d) in HOLIDAYS:
                continue
            meetings += [{**b, 'date': str(d)} for b in blocks if b['weekday'] == d.isoweekday()]
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
    remark = REMARK
    if reasons:
        remark += ' 일정 미생성: ' + '; '.join(reasons)
    remark += ' 수강 대상: ' + ', '.join(depts) + '; 원문 비고: ' + '; '.join(sorted({x['education'].get('비고', '') for x in src} - {''}))
    try:
        credits = float(fields['학점'][0]) if len(fields['학점']) == 1 else None
    except ValueError:
        credits = None
    return {'sourceId': 'daegu-2026-2-registration-' + code, 'referenceKind': '수강번호', 'canonicalSubjectCodePublished': False,
            'nativeSectionPublished': False, 'campus': 'main',
            'campusEvidence': 'academyinfo:0000084 본교 institution scope; comprehensive timetable has no per-offering campus selector, no inferred room location',
            'academicYear': 2026, 'semester': '2', 'courseCode': code, 'courseName': e['교과목명'], 'courseNameAliases': fields['교과목명'],
            'section': '', 'professor': e.get('담당교수', '') if '담당교수' not in conflicts else '', 'credits': credits,
            'classification': cat, 'sourceClassificationAliases': cats, 'departments': depts, 'departmentCredits': depcredit,
            'departmentClassifications': depclass, 'departmentRemarks': {k: remark + '\n' + v for k, v in depremarks.items()},
            'remarks': remark, 'sourceSchedule': source, 'sourceClassroom': room, 'sourceScheduleAliases': fields['강의시간'],
            'sourceClassroomAliases': fields['강의실'], 'scheduleStatus': 'scheduled' if meetings else 'unrecognized',
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-14'}, 'schedules': meetings, 'sourceSnapshotSchedules': blocks,
            'publicEducationRows': src,
            'datesMeaning': 'published ordinary regular teaching through December7, without autonomous makeups or exams; attendance unconfirmed'}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--lines', required=True, help='daegu_pdf_columns.swift output with edges 0,600')
    p.add_argument('--cols', required=True, help='daegu_pdf_columns.swift output with the 12 major-table column edges')
    p.add_argument('--offerings', required=True, help='2026-10-08 educational-source-offerings.json')
    p.add_argument('--closures', required=True, help='closure-educational-rows.json (official closure list)')
    p.add_argument('--special', required=True, help='special-operation-registration-numbers.json')
    p.add_argument('--asset', required=True)
    p.add_argument('--report', required=True)
    a = p.parse_args()
    load = lambda f: json.loads(Path(f).read_text(encoding='utf-8'))
    lines = {x['page']: x['lines'] for x in load(a.lines)}
    cols = {x['page']: x['lines'] for x in load(a.cols)}
    old = load(a.offerings)
    rows = extract_major_rows(lines, cols)
    # Self-check: the rebuild must reproduce every earlier 전공 row field for field.
    index = {(r['sourcePage'], r['nativeRegistrationNumber']): r for r in rows}
    z = lambda s: re.sub(r'\s+', '', s or '')
    compared = 0
    missing = []
    # extract_major_rows rebuilds only 전공 강의시간표, so only the earlier 전공 rows can be
    # compared; the other printed tables still count as known registration numbers below.
    earlier_major = [o for o in old if (o.get('sourceTitleLines') or [''])[0] == MAJOR_TITLE]
    for o in earlier_major:
        r = index.get((o['sourcePage'], o['nativeRegistrationNumber']))
        if r is None:
            missing.append((o['sourcePage'], o['nativeRegistrationNumber']))
            continue
        compared += 1
        for k, v in o['education'].items():
            assert z(v) == z(r['education'].get(k)), (o['sourcePage'], o['nativeRegistrationNumber'], k)
    # A dropped continuation page must fail here, not write an incomplete asset.
    assert not missing and compared == len(earlier_major), f'earlier major rows not rebuilt: {missing[:10]}'
    known = {o['nativeRegistrationNumber'] for o in old}
    known_keys = {(o['sourcePage'], o['nativeRegistrationNumber']) for o in old}
    added_rows = [r for r in rows if (r['sourcePage'], r['nativeRegistrationNumber']) not in known_keys]
    assert all(r['nativeRegistrationNumber'] not in known for r in added_rows), 'new row for an existing course'
    closed = {r['education']['수강번호'] for r in load(a.closures)} | {'1316', '2210'}
    special = set(load(a.special))
    by = collections.defaultdict(list)
    for r in added_rows:
        by[r['nativeRegistrationNumber']].append(r)
    asset = load(a.asset)
    before = json.dumps(asset['courses'], ensure_ascii=False, sort_keys=True)
    existing = {c['courseCode'] for c in asset['courses']}
    new = [build_course(code, src, special) for code, src in sorted(by.items()) if code not in closed]
    assert not existing & {c['courseCode'] for c in new}
    asset['courses'] = sorted(asset['courses'] + new, key=lambda c: c['courseCode'])
    kept = [c for c in asset['courses'] if c['courseCode'] in existing]
    assert json.dumps(sorted(kept, key=lambda c: c['courseCode']), ensure_ascii=False, sort_keys=True) == before
    Path(a.asset).write_text(json.dumps(asset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    report = {'rebuiltMajorRows': len(rows), 'comparedWithEarlierRows': compared, 'fieldDifferences': 0,
              'newRegistrationNumbers': sorted(by), 'closedAmongNew': sorted(set(by) & closed),
              'addedCourses': len(new), 'addedScheduled': sum(c['scheduleStatus'] == 'scheduled' for c in new),
              'addedUnrecognized': sum(c['scheduleStatus'] == 'unrecognized' for c in new), 'totalCourses': len(asset['courses'])}
    Path(a.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'newRegistrationNumbers'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
