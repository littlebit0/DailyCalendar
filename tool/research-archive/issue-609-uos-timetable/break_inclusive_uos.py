#!/usr/bin/env python3
"""UOS 시간표: 교시 슬롯을 쉬는 시간 포함 60분으로 늘리고 연속 구간을 합친다."""
import json, sys
path = sys.argv[1]
d = json.load(open(path, encoding='utf-8'))
before = after = changed = merged = 0
for c in d['courses']:
    ms = c['schedules']
    if not ms: continue
    before += len(ms)
    new = [dict(m, endMinute=m['endMinute'] + 10) for m in ms]
    out = []
    for m in new:
        p = next((q for q in out if q['weekday'] == m['weekday'] and q['classroom'] == m['classroom']
                  and m['startMinute'] - q['endMinute'] < 60 and q['startMinute'] - m['endMinute'] < 60), None)
        if p:
            p['startMinute'] = min(p['startMinute'], m['startMinute'])
            p['endMinute'] = max(p['endMinute'], m['endMinute'])
        else:
            out.append(m)
    if len(out) < len(ms): merged += 1
    after += len(out)
    c['schedules'] = out
    changed += 1
json.dump(d, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open(path, 'a').write('\n')
print(dict(before=before, after=after, changed=changed, merged=merged))
