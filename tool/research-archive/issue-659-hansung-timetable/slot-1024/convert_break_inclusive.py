"""Hansung: 75/50-minute blocks -> break-inclusive slots, then merge adjacent same-room segments."""
import json, sys
P = sys.argv[1]
d = json.load(open(P))
B75 = [(540,615),(630,705),(720,795),(810,885),(900,975),(990,1065),(1080,1155),(1165,1240),(1245,1320)]
S75 = [630,720,810,900,990,1080,1165,1245,1335]  # last: regular 75+15 slot
B50 = [(540+i*60,540+i*60+50) for i in range(9)] + [(1080,1130),(1135,1185),(1190,1240),(1245,1295),(1300,1350)]
S50 = [b[0]+60 for b in B50[:9]]
S50 = S50[:9] + [1135,1190,1245,1300,1360]
def tables(w):
    if w in (1,3,4): return B75,S75
    if w in (2,5): return B50,S50
    return None
stats = dict(before=0, after=0, changed=set(), merged=set(), kept=0)
for c in d['courses']:
    out = []
    for s in c['schedules']:
        stats['before'] += 1
        t = tables(s['weekday'])
        n = dict(s)
        if t:
            B, S = t
            starts = [b[0] for b in B]; ends = {b[1]: i for i, b in enumerate(B)}
            if s['startMinute'] in starts and s['endMinute'] in ends:
                n['endMinute'] = S[ends[s['endMinute']]]
            else: stats['kept'] += 1
        else: stats['kept'] += 1
        out.append(n)
    res = []
    for n in out:
        for m in res:
            if (m['date'], m['classroom']) == (n['date'], n['classroom']) and m['startMinute'] <= n['startMinute'] \
               and n['startMinute'] - m['endMinute'] < 60 and n['weekday'] == m['weekday']:
                if n['endMinute'] > m['endMinute']: m['endMinute'] = n['endMinute']
                stats['merged'].add(c['sourceId']); break
        else: res.append(n)
    # order-insensitive guard: rerun merge on sorted? keep input order
    if res != c['schedules']: stats['changed'].add(c['sourceId'])
    stats['after'] += len(res)
    c['schedules'] = res
open(P, 'w').write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print({k: (len(v) if isinstance(v, set) else v) for k, v in stats.items()})
