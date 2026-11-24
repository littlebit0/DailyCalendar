#!/usr/bin/env python3
"""Sogang 2026-2: show the weekly-reservation note in the remarks the app displays.

UniversityCourse.remarks prefers departmentRemarks over the top-level remarks, so the
2026-11-23 weekly-reservation note (top-level `remarks`, `userDecisionWeeklyReservation.note`,
and the PHY4201·PHY4204 syllabus note) was hidden. For every such course this appends the
note to each departmentRemarks value and rewrites the older exam-only line, which said the
course offered only the exam appointment and would not be expanded into weekly classes:
"공개 시험 약속만 제공" becomes "공개 시험 약속" and the sentences that contradict the weekly
reservation are dropped. The exam date, time, room and exam-mode sentences stay; source lines
(수강대상, 비고, 공개시험일자 …) are untouched.

    python3 tool/timetable/patch_sogang_weekly_reservation_remarks.py

Re-running is a no-op.
"""
import json
from pathlib import Path

ASSET = Path('assets/timetable/sogang-unknown-2026-2.json')
OLD_HEAD, NEW_HEAD = '공식 현재2026-2 공개 시험 약속만 제공:', '공식 현재2026-2 공개 시험 약속:'
# Sentences of the exam-only line that contradict the weekly reservation.
CONTRADICTIONS = (
    ' 정규수업·영상/현장 운영 날짜는 여전히 미확인입니다.',
    '하며 시험 이후 주간 수업으로 확장하지 않습니다.',
    ' 정규운영은 미확인이고 이시험 이후 주간수업을 확대하지 않습니다.',
)
REPLACEMENTS = {CONTRADICTIONS[1]: '합니다.'}


def rewrite_line(line):
    if not line.startswith(OLD_HEAD):
        return line
    line = NEW_HEAD + line[len(OLD_HEAD):]
    for old in CONTRADICTIONS:
        line = line.replace(old, REPLACEMENTS.get(old, ''))
    return line


def note_for(course):
    if 'userDecisionWeeklyReservation' in course:
        return course['userDecisionWeeklyReservation']['note']
    if 'syllabusClockEvidence' in course:
        return course['remarks']
    return None


def patch(data):
    changed = 0
    for c in data['courses']:
        note = note_for(c)
        if not note:
            continue
        before = dict(c['departmentRemarks'])
        for dept, value in c['departmentRemarks'].items():
            lines = [rewrite_line(line) for line in value.split('\n')] if value else []
            if note not in lines:
                lines.append(note)
            c['departmentRemarks'][dept] = '\n'.join(lines)
        if '만 제공' in json.dumps(c['departmentRemarks'], ensure_ascii=False) \
                or any(s.strip() in v for s in CONTRADICTIONS for v in c['departmentRemarks'].values()):
            raise ValueError(f"{c['sourceId']}: unhandled exam-only wording")
        changed += c['departmentRemarks'] != before
    return changed


def main():
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    changed = patch(data)
    ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'patched {changed}')


if __name__ == '__main__':
    main()
