import json, collections, sys
sys.path.insert(0, 'scripts')
from classify import *
off = json.load(open('official.json'))
ex = {f"{x['courseCode']}-{x['section']}": x for x in json.load(open(sys.argv[1]))['courses']}
c = collections.Counter(); s = collections.defaultdict(list)
for k, L in off.items():
    st, why, p = decide(L)
    tag = ('existing' if k in ex else 'new')
    c[(tag, st, why)] += 1
    s[(tag, st, why)].append((k, [(l['page'], l['time'], l['room']) for l in L][:4]))
    if k in ex and st == 'scheduled':
        ms = meetings(slots_shared(p['time']) if p['room'] is None else slots_std(p['time']), p['room'])
        a = sorted((m['weekday'], m['startMinute'], m['endMinute']) for m in ms)
        b = sorted((m['weekday'], m['startMinute'], m['endMinute']) for m in ex[k]['schedules'])
        if a != b: c['EXISTING-MISMATCH'] += 1; print('MISMATCH', k, a, b)
for k, v in sorted(c.items(), key=str): print(v, k)
for k, v in s.items():
    if k[1] != 'scheduled' or k[2]:
        print('##', k, len(v))
        for i in v[:40]: print('   ', i)
