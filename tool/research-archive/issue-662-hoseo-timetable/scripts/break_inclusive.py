"""호서대 교시 계산 구간을 쉬는 시간 포함 60분 슬롯으로 고치고 연속 교시를 합친다 (사용자 결정 2026-10-24)."""
import json, sys
from collections import Counter
ROOT = sys.argv[1]; APPLY = len(sys.argv) > 2 and sys.argv[2] == 'apply'
OLD_TAIL = '교시당 50분)에 따르며 연속 교시는 한 블록으로 합칩니다.'
NEW_TAIL = '교시당 수업 50분+쉬는 시간 10분=60분 슬롯)에 따르며 연속 교시는 한 블록으로 합칩니다.'

def merge(rows, key_fields):
    rows = sorted(rows, key=lambda r: tuple(r[k] for k in key_fields) + (r['startMinute'],))
    out = []
    for r in rows:
        p = out[-1] if out else None
        if p and all(p[k] == r[k] for k in key_fields) and r['startMinute'] - p['endMinute'] < 60:
            p['endMinute'] = max(p['endMinute'], r['endMinute'])
        else:
            out.append(dict(r))
    return out

st = Counter()
for f in ['asan', 'cheonan', 'unknown']:
    p = f'{ROOT}/assets/timetable/hoseo-{f}-2026-2.json'
    d = json.load(open(p))
    for c in d['courses']:
        if c['scheduleStatus'] != 'scheduled': continue
        old = c['schedules']
        # 교시 슬롯은 끝 시각에 쉬는 시간 10분을 더한다
        rows = [dict(r, endMinute=r['endMinute'] + 10) for r in old]
        new = merge(rows, ['date', 'weekday', 'classroom'])
        new.sort(key=lambda r: (r['date'], r['startMinute']))
        st['before'] += len(old); st['after'] += len(new); st['courses'] += 1
        if len(new) != len(old):
            st['merged'] += 1
            c['_merged'] = True
        c['schedules'] = new
        blocks = c['metadata'].get('nativeClockRoomBlocks') or []
        if blocks:
            nb = merge([dict(b, endMinute=b['endMinute'] + 10) for b in blocks], ['weekday', 'classroom'])
            c['metadata']['nativeClockRoomBlocks'] = nb
        c['remarks'] = c['remarks'].replace('교시당 50분)에 따르며 연속 교시는 한 블록으로 합칩니다.', NEW_TAIL)
    st['changed'] += st['courses'] - st.get('x', 0)
    for c in d['courses']: c.pop('_merged', None)
    st[f'{f}_courses'] = sum(1 for c in d['courses'] if c['scheduleStatus'] == 'scheduled')
    if APPLY:
        json.dump(d, open(p, 'w'), ensure_ascii=False, indent=2); open(p, 'a').write('\n')
print(dict(st))
