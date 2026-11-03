"""Prepare every actual current XLS identity; unresolved campus stays null.

This research candidate is intentionally not a registered production catalogue.
It keeps original remote/practice periods without inventing attendance dates.
"""
import json
import re
from collections import defaultdict
from pathlib import Path
ROOT = Path(__file__).parent
DAYS = '월화수목금토일'
SPECIAL = re.compile(r'현장실습|집중이수|부트캠프|대학생활설계와비전|사회봉사')


def parse_clock(raw, room):
    parts = [x.strip() for x in (raw or '').split(',')]
    slots = []
    for part in parts:
        match = re.fullmatch(r'([월화수목금토일])(\d{1,2})(?:~(\d{1,2}))?',part)
        if not match:
            return []
        day, first, last = match.groups()
        first, last = int(first), int(last or first)
        if not 0 <= first <= last <= 14:
            return []
        slots.append({'weekday':DAYS.index(day)+1,'startMinute':540+first*60,
                      'endMinute':590+last*60,'classroom':room})
    return slots


def prepare(rows, credit_rows, campus_rows=(), curriculum_rows=()):
    if len(rows) != 2627:
        raise ValueError('Changed source scope: review all 4 current sheets')
    credits = defaultdict(set)
    credit_evidence = defaultdict(set)
    for record in credit_rows:
        credits[record['code']].add(float(record['credit']))
        credit_evidence[record['code']].add('current PDF actual course code')
    for record in curriculum_rows:
        actual_names={r['values'][2] for r in rows if r['code']==record['code']}
        if actual_names != {record['courseName']}:
            raise ValueError('Current curriculum identity/name mismatch')
        if not record.get('identitySources') or not record.get('creditSource'):
            raise ValueError('Missing official curriculum join provenance')
        credits[record['code']].add(float(record['credit']))
        credit_evidence[record['code']].add('current official curriculum joined through current exact code/name')
    campus_by_key = defaultdict(set)
    for record in campus_rows:
        campus_by_key[record['code'],record['section']].add(record['campus'])
    grouped = defaultdict(list)
    for record in rows:
        if not re.fullmatch(r'0[A-Z0-9]{7}',record['code']) or not re.fullmatch(r'[A-Z0-9]{2}',record['section']):
            raise ValueError('Invalid actual course identity')
        grouped[record['code'],record['section']].append(record)
    result, audit = [], {'unresolvedCampus':[],'campusAllocationRoomDifferences':[],
        'missingCredit':[],'unresolvedAttendance':[],'duplicateSourceOccurrences':len(rows)-len(grouped)}
    for (code, section), records in grouped.items():
        bodies=[r['values'] for r in records]
        if len({(v[2],v[8],v[9],v[10],v[11]) for v in bodies}) != 1:
            raise ValueError('Conflicting actual identity/time/room')
        v=bodies[0]
        room=' / '.join(dict.fromkeys(str(x) for x in v[10:12] if x))
        room_campuses=[]
        if '아)' in room:room_campuses.append('asan')
        if '천)' in room:room_campuses.append('cheonan')
        assigned='cheonan' if v[8]=='주간(천안)' else None
        campus=assigned or (room_campuses[0] if len(room_campuses)==1 else None)
        if assigned and room_campuses and assigned not in room_campuses:
            audit['campusAllocationRoomDifferences'].append([code,section])
        printed = campus_by_key.get((code,section),set())
        if len(printed)>1:raise ValueError('Contradictory current explicit PDF campus')
        if campus is None and len(printed)==1:campus=next(iter(printed))
        if campus is None:audit['unresolvedCampus'].append([code,section])
        credit_values=credits.get(code,set())
        credit=next(iter(credit_values)) if len(credit_values)==1 else None
        if credit is None:audit['missingCredit'].append([code,section])
        methods={x[4] for x in bodies}
        meetings=parse_clock(v[9],room)
        reason=''
        if any(m and m.startswith('원격') for m in methods):
            reason='원격 강좌의 실제 대면/온라인 출석 시각과 별도 기간 확인 필요'
        elif SPECIAL.search(v[2]):
            reason='상담·집중·현장실습의 실제 시행 날짜 미확정'
        elif not v[9]:
            reason='공개 개설현황에 수업시간 미게시'
        elif not meetings:
            reason='공식 교시 표기 해석 미확정'
        if reason:
            meetings=[]
            audit['unresolvedAttendance'].append({'code':code,'section':section,'reason':reason})
        departments=list(dict.fromkeys(x[1] for x in bodies))
        source_id=f'hoseo/2026/2/{code}/{section}'
        result.append({'sourceId':source_id,'universityId':'hoseo','campus':campus or 'unknown',
            'campusEvidence':'current explicit allocation/room' if campus else 'actual source campus not verified; technical unknown filter only',
            'academicYear':2026,'semester':'2','courseCode':code,'section':section,
            'courseName':v[2],'professor':' / '.join(dict.fromkeys(x[5] for x in bodies if x[5])),
            'credits':credit,'creditEvidence':' / '.join(sorted(credit_evidence[code])) if credit is not None else 'XLS has no credit column; PDF value not verified',
            'departmentCredits':{department:credit for department in departments} if credit is not None else {},
            'sourceSchedule':v[9] or '', 'sourceClassroom':room,
            'scheduleStatus':'unrecognized' if reason else 'scheduled','schedules':meetings,
            'departments':departments,'departmentClassifications':{x[1]:x[3] for x in bodies},
            'departmentRemarks':{x[1]:'\n'.join(str(z) for z in [x[12],reason,'공식 수업방법: '+str(x[4]),'공식 수업구분: '+str(x[8])] if z) for x in bodies},
            'actualRoomCampuses':room_campuses,
            'sourceOccurrences':[{'sheet':r['sourceSheet'],'row':r['sourceRow']} for r in records]})
    return {'productionReady':False,'completionClaim':False,'academicYear':2026,'semester':'2',
            'courses':result,'audit':audit,'remainingVerification':['current active closures/latest changes','remaining campus allocation unresolved identities','special attendance dates','credit misses preserved as null']}


if __name__=='__main__':
    result=prepare(json.loads((ROOT/'hoseo-current-actual-rows.json').read_text()),
                   json.loads((ROOT/'hoseo-pdf-course-credit-complete-extraction.json').read_text()),
                   json.loads((ROOT/'hoseo-current-pdf-explicit-campus-rows.json').read_text()),
                   json.loads((ROOT/'hoseo-current-curriculum-credit-join.json').read_text()))
    (ROOT/'hoseo-current-whole-candidate-unregistered.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Actual identities',len(result['courses']))
    print({key:len(value) if isinstance(value,list) else value for key,value in result['audit'].items()})
