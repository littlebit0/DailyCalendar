"""호서대 0·9~14교시 확정. 근거: 수업시간표 책자 p.152 `19. 시간표`(교시별 시각), p.4, 시행규칙 제44조."""
import json, re, sys
from collections import Counter, defaultdict
ROOT = sys.argv[1]
APPLY = len(sys.argv) > 2 and sys.argv[2] == 'apply'
FILES = ['asan', 'cheonan', 'unknown']
DAY = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5}
data = {f: json.load(open(f'{ROOT}/assets/timetable/hoseo-{f}-2026-2.json')) for f in FILES}
allc = [c for f in FILES for c in data[f]['courses']]
dates = defaultdict(set)
for c in allc:
    if c['scheduleStatus'] == 'scheduled':
        for s in c['schedules']:
            dates[s['weekday']].add(s['date'])
seg_re = re.compile(r'^([월화수목금토])(\d+)(?:~(\d+))?$')

def parse(s):
    out = []
    for part in s.split(','):
        m = seg_re.match(part.strip())
        if not m: return None
        d, a, b = m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))
        if d not in DAY or a > b or b > 14: return None
        out.append((DAY[d], a, b))
    return out

reasons = Counter(); done = []
for c in allc:
    if c['scheduleStatus'] != 'unrecognized': continue
    md = c['metadata']; ms = [m or '' for m in md['sourceNativeTeachingMethods']]
    s = (c['sourceSchedule'] or '').strip()
    if any('원격' in m for m in ms) or not any(ms): reasons['원격·하이브리드·빈 수업방법'] += 1; continue
    if len(md['originalEducationalRecords']) > 1: reasons['강사명만 다른 공동 강의 행'] += 1; continue
    if md['sourceNativeStudyType'] not in ('주간', '주간(천안)'): reasons['2부(야간)'] += 1; continue
    if not s: reasons['요일·교시 없음'] += 1; continue
    if '토' in s: reasons['토요일'] += 1; continue
    segs = parse(s)
    if segs is None: reasons['파싱 불가'] += 1; continue
    byday = defaultdict(list)
    for d, a, b in segs: byday[d].append((a, b))
    if any(x[1] >= y[0] for v in byday.values() for x in [sorted(v)[0]] for y in sorted(v)[1:2]) and any(
            sorted(v)[i][1] >= sorted(v)[i+1][0] for v in byday.values() for i in range(len(v)-1)):
        reasons['같은 날 구간 겹침'] += 1; continue
    rooms = [c['sourceClassroom']] if c['sourceClassroom'] else []
    rawroom = c['sourceClassroom'] or ''
    room = ''
    if len(segs) == 1:
        parts = [p.strip() for p in rawroom.split('/') if p.strip()]
        room = parts[0] if len(parts) == 1 else ('강의실1: %s / 강의실2: %s' % tuple(parts) if len(parts) == 2 else '')
    else:
        parts = [p.strip() for p in rawroom.split('/') if p.strip()]
        room = parts[0] if len(parts) == 1 else ''
    sch = []
    for d, a, b in sorted(segs):
        for dt in sorted(dates[d]):
            sch.append({'date': dt, 'weekday': d, 'startMinute': 540 + 60*a, 'endMinute': 540 + 60*b + 50, 'classroom': room})
    sch.sort(key=lambda x: (x['date'], x['startMinute']))
    if APPLY:
        c['schedules'] = sch; c['scheduleStatus'] = 'scheduled'
        c['remarks'] = c['remarks'].split(' 예약보류:')[0].rstrip().removesuffix('원문비고:').rstrip() + ' 0·9~14교시 시작 시각은 수업시간표 책자 p.152 `19. 시간표`(0교시 09:00~14교시 23:00 시작, 교시당 50분)에 따르며 연속 교시는 한 블록으로 합칩니다.'
        md['heldReason'] = ''; md['reservationHoldReasons'] = []
        md['periodTimeBasis'] = '수업시간표 책자 2026-2 p.152 19. 시간표'
        md['nativeClockRoomBlocks'] = [{'weekday': d, 'startMinute': 540+60*a, 'endMinute': 540+60*b+50, 'classroom': room} for d, a, b in sorted(segs)] if room else []
    done.append((c['sourceId'], s, room))
    reasons['확정(0·9~14교시 포함 평일 주간 대면)'] += 1
print(json.dumps(reasons, ensure_ascii=False, indent=1))
print(len(done), Counter(('0' in re.findall(r'\d+', s) or any(int(x)>8 for x in re.findall(r'\d+', s))) for _, s, _ in done))
if APPLY:
    for f in FILES:
        json.dump(data[f], open(f'{ROOT}/assets/timetable/hoseo-{f}-2026-2.json', 'w'), ensure_ascii=False, indent=2)
        open(f'{ROOT}/assets/timetable/hoseo-{f}-2026-2.json', 'a').write('\n')
