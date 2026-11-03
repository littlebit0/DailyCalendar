"""Narrow current social-work classroom plans; never invent institution practice dates."""
import collections
import copy
import datetime as dt
import hashlib
import json
import re
from prepare_cuk_published_regular_candidate import ROOT, FIRST, LAST, HOLIDAYS, DAYS, REGULAR_NOTE, load

SOURCE = 'catholic-unknown-2026-2.published-regular-1013-candidate-20261008.json'
KEYS = {('02849', '01'), ('02849', '02')}
NOTE = '방학 중 기관실습과 별도로 학교가 현재 공시한 학기 중 분반 정규수업 계획만 표시합니다. 기관실습 일정은 포함하지 않습니다.'

def prepare():
    data = copy.deepcopy(load(SOURCE))
    audit = copy.deepcopy(load('cuk-published-regular-1013-candidate-audit-20261008.json'))
    for course in data['courses']:
        if (course['courseCode'], course['section']) not in KEYS:
            continue
        assert not course['schedules']
        assert course['professor'] == {'01': '이용표', '02': '박혜준'}[course['section']]
        blocks = []
        for day, begin, finish, room in re.findall(r'([월화수목금토일])(\d+)(?:~(\d+))?\(([^()]*)\)', course['sourceSchedule']):
            blocks.append({'weekday': DAYS.index(day) + 1, 'firstPeriod': int(begin), 'lastPeriod': int(finish or begin), 'classroom': room})
        date = FIRST
        while date <= LAST:
            if date.isoformat() not in HOLIDAYS:
                for block in blocks:
                    if date.isoweekday() != block['weekday']:
                        continue
                    periods = [p for p in range(block['firstPeriod'], block['lastPeriod'] + 1)
                               if not (date.isoformat() == '2026-09-09' and p in (2, 3))]
                    groups = []
                    for p in periods:
                        if not groups or p != groups[-1][-1] + 1:
                            groups.append([])
                        groups[-1].append(p)
                    for group in groups:
                        course['schedules'].append({'weekday': date.isoweekday(), 'startMinute': (group[0] + 8) * 60,
                                                    'endMinute': (group[-1] + 8) * 60 + 50,
                                                    'classroom': block['classroom'], 'date': date.isoformat()})
            date += dt.timedelta(days=1)
        course['scheduleStatus'] = 'scheduled'
        course['departmentRemarks'] = {d: '\n'.join(x for x in [course['sourceRemarks'], REGULAR_NOTE, NOTE] if x)
                                      for d in course['departments']}
        course['sourceEducation']['currentOperatingProof'] = 'Official2026-2socialwork notice274404: enroll in instructor section based on past vacation institution practice; actual regular class-time conflicts may require section change.'
        course['sourceEducation']['limits'] += ' Institution practice dates are not generated. This is the currently published classroom section plan.'
        row = next(r for r in audit['courses'] if (r['code'], r['section']) == (course['courseCode'], course['section']))
        row.update(reason=None, sourceClockBlocks=blocks, datedPlannedMeetings=len(course['schedules']))
    name = 'catholic-unknown-2026-2.published-regular-1015-candidate-20261008.json'
    path = ROOT / name
    assert not path.exists(), 'Immutable candidate exists; do not overwrite'
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    audit.update(candidateFile=name, candidateSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                 scheduleCounts=dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
                 reasonCounts=dict(collections.Counter(r['reason'] or 'plannedRegularTimetable' for r in audit['courses'])),
                 datedPlannedMeetings=sum(len(c['schedules']) for c in data['courses']),
                 additionalSocialWorkClassroomSections=2,
                 socialWorkEvidence='cuk-current2026-2-socialwork-section-operation-20261008.json',
                 socialWorkLimit=NOTE)
    out = ROOT / 'cuk-published-regular-1015-candidate-audit-20261008.json'
    assert not out.exists()
    out.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k != 'courses'}, ensure_ascii=False))

if __name__ == '__main__':
    prepare()
