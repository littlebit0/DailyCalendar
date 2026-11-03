"""#570: 공주대 주간 교시 슬롯을 쉬는 시간 포함(50분+10분=60분)으로 늘리고 연속 구간을 합친다.
원문 시계 시각(HH:mm) 강좌는 건드리지 않는다. 저장소 루트에서 실행."""
import json, re, glob, sys

stats = dict(before=0, after=0, changed=0, merged=0)
for f in sorted(glob.glob('assets/timetable/kongju-*-2026-2.json')):
    d = json.load(open(f))
    for c in d['courses']:
        sch = c['schedules']
        if not sch or re.search(r'\d\d:\d\d', c['sourceSchedule']):
            stats['before'] += len(sch); stats['after'] += len(sch)
            continue
        new = []
        for s in sorted(sch, key=lambda s: (s['date'], s['startMinute'])):
            assert s['startMinute'] % 60 == 0 and s['endMinute'] % 60 == 50, (c['sourceId'], s)
            s = dict(s, endMinute=s['endMinute'] + 10)
            p = new[-1] if new else None
            if (p and p['date'] == s['date'] and p['classroom'] == s['classroom']
                    and s['startMinute'] - p['endMinute'] < 60):
                p['endMinute'] = max(p['endMinute'], s['endMinute'])
            else:
                new.append(s)
        stats['before'] += len(sch); stats['after'] += len(new)
        stats['changed'] += 1
        if len(new) < len(sch): stats['merged'] += 1
        c['schedules'] = new
    open(f, 'w').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
print(stats)
