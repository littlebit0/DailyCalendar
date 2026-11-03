"""Research v2: retain frozen v1 and release only explicit native correspondences."""
import collections
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

R = Path(__file__).parent
BASE = R.parent
CLOCK = json.loads((BASE/'jeju-current-source-proof-v1.json').read_text())['clockMinutes']

def parse(raw):
    # Each room directly precedes a native day-period run, or directly follows
    # one native day-period. Never distribute parallel room lists across days.
    raw = ''.join(part if part.startswith('[') else re.sub(r'\s+', '', part).replace('+', '') for part in re.split(r'(\[[^]]*\])', raw))
    spans = []
    parts = list(re.finditer(r'\[([^\[\]]+)\]((?:[월화수목금토일]\d+[AB]?)+)', raw))
    if parts and ''.join(p[0] for p in parts) == raw:
        tokens = [(d, p, m[1]) for m in parts
                  for d, p in re.findall(r'([월화수목금토일])(\d+[AB]?)', m[2])]
        grammar = 'room-first-explicit-run'
    else:
        parts = list(re.finditer(r'([월화수목금토일])(\d+[AB]?)\[([^\[\]]+)\]', raw))
        if not parts or ''.join(p[0] for p in parts) != raw:
            return [], '원본 강의실·교시 대응 미확인', ''
        tokens = [(p[1], p[2], p[3]) for p in parts]
        grammar = 'period-first-explicit-pair'
    for d, p, room in tokens:
        if not room.strip():
            return [], '원본 강의실·교시 대응 미확인', grammar
        day = '월화수목금토일'.index(d)+1
        if day > 5 or p not in CLOCK:
            return [], '공식 주간·야간 시각 범위 밖', grammar
        start, end = CLOCK[p]
        span = dict(weekday=day, startMinute=start, endMinute=end, classroom=room)
        if span not in spans:
            spans.append(span)
    for a in spans:
        for b in spans:
            if a is not b and a['weekday'] == b['weekday'] and max(a['startMinute'], b['startMinute']) < min(a['endMinute'], b['endMinute']):
                return [], '같은 요일 시각 중복·복수 강의실 원문 충돌', grammar
    return spans, '', grammar

def dates(spans):
    meetings = []
    day = dt.date(2026,9,1)
    while day <= dt.date(2026,12,7):
        if not dt.date(2026,10,20) <= day <= dt.date(2026,10,26) and day.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
            meetings.extend(dict(s,date=day.isoformat()) for s in spans if s['weekday'] == day.isoweekday())
        day += dt.timedelta(days=1)
    return meetings

added=[]
counts={}
held=collections.Counter()
for campus in ['ara','sara','unknown']:
    old=json.loads((BASE/f'jeju-{campus}-2026-2.reservation-planned-v1.json').read_text())
    data=copy.deepcopy(old)
    for c, prior in zip(data['courses'], old['courses']):
        if prior['schedules']:
            assert c == prior
            continue
        native=c['metadata']['originalEducationalFields']
        if native['operatingReview'] != 'ordinary-clock-current-operation-review':
            continue
        oldreason=c['metadata']['heldReason']
        if oldreason not in ['별도 학사·특수운영 개별 날짜 미확인','원본 강의실·교시 대응 미확인']:
            continue
        if native['department'].startswith('의과대학 '):
            continue  # Current guide explicitly requires separate medical calendar.
        if any(s in native['rawTimeAndRoom']+' '+native['title'] for s in ['플립','Flipped','현장실습','실습기관','봉사','집중']):
            continue
        spans, reason, grammar=parse(native['rawTimeAndRoom'])
        if reason:
            c['metadata'].update(v2ReviewReason=reason, v2PreviousHeldReason=oldreason, heldReason=reason)
            c['remarks']=c['remarks'].replace(' 예약 보류: '+oldreason, ' 예약 보류: '+reason)
            continue
        c['schedules']=dates(spans)
        c['scheduleStatus']='scheduled'
        c['sourceClassroom']=' / '.join(dict.fromkeys(s['classroom'] for s in spans))
        c['metadata'].update(heldReason='',v2PreviousHeldReason=oldreason, nativeRoomPeriodGrammar=grammar,
            programDateScope='Future-convergence general pre-makeup window; final/end next Saturday excluded' if native['department'].startswith('미래융합') else 'General undergraduate current guide; veterinary not medical separate-calendar scope',
            sourcePeriodSpans=spans)
        c['remarks']=c['remarks'].replace(' 예약 보류: '+oldreason,'')+' 원문 교시·강의실 직접 대응으로 일반 예약을 제공합니다. 수의과대학은 의과대학 별도학사 문구와 구분합니다. 미래융합대학의 기말·종강 다음 토요일 예외 기간은 생성하지 않습니다. 개별 운영·최신 변경은 미확인입니다.'
        added.append(dict(sourceId=c['sourceId'],enrollmentNumber=native['enrollmentNumber'],department=native['department'],rawTimeAndRoom=native['rawTimeAndRoom'],previousHeldReason=oldreason,grammar=grammar,spans=spans,dates=len(c['schedules'])))
    data['researchRevision']='ordinary-room-program-followup-v2'
    (R/f'jeju-{campus}-2026-2.reservation-planned-v2.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    counts[campus]=dict(rows=len(data['courses']),scheduled=sum(bool(c['schedules']) for c in data['courses']),dates=sum(len(c['schedules']) for c in data['courses']))
    held.update(c['metadata'].get('v2ReviewReason',c['metadata']['heldReason']) for c in data['courses'] if not c['schedules'])
audit=dict(researchOnly=True,completionClaim=False,counts=counts,addedCount=len(added),addedDates=sum(x['dates'] for x in added),addedByDepartment=dict(collections.Counter(x['department'] for x in added)),held=dict(held),added=added,oldScheduledDeepPreserved=1510,oldDatesDeepPreserved=52732,officialSubjectCodeCount=531,currentWholeFreshnessOrClosuresVerified=False)
(R/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k!='added'},ensure_ascii=False))
