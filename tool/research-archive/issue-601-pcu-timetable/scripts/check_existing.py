import json, collections, sys
sys.path.insert(0, 'scripts')
from timeconv import *
off = json.load(open('official.json'))
ex = json.load(open(sys.argv[1]))['courses']
cnt = collections.Counter(); samples = collections.defaultdict(list)
for x in ex:
    k = f"{x['courseCode']}-{x['section']}"
    L = off.get(k)
    if not L:
        cnt['not-in-official'] += 1; samples['not-in-official'].append(k); continue
    times = {nfkc(l['time']) for l in L if l['time']}
    prim = L[0]
    t = prim['time']
    sl = slots_shared(t) if prim['room'] is None else slots_std(t)
    exs = [(m['weekday'], m['startMinute'], m['endMinute']) for m in x['schedules']]
    if sl is None:
        cnt['existing-nonstd'] += 1; samples['existing-nonstd'].append((k, t, exs)); 
    else:
        ms = meetings(sl, prim['room'])
        mine = [(m['weekday'], m['startMinute'], m['endMinute']) for m in ms]
        if sorted(mine) != sorted(exs):
            cnt['time-diff'] += 1; samples['time-diff'].append((k, t, mine, exs))
        else:
            cnt['time-same'] += 1
    if len(times) > 1:
        cnt['listing-conflict'] += 1; samples['listing-conflict'].append((k, [(l['page'], l['time'], l['room']) for l in L]))
    if any(not l['time'] for l in L) and times:
        cnt['blank-vs-time'] += 1; samples['blank-vs-time'].append((k, [(l['page'], l['time']) for l in L]))
    # field check vs primary
    for f, v in [('courseName', prim['name']), ('professor', prim['prof']), ('classification', prim['cls'])]:
        if x[f].replace(' ', '') != v:
            cnt['field-' + f] += 1; samples['field-' + f].append((k, x[f], v))
print(dict(cnt))
for s, v in samples.items():
    print('##', s, len(v))
    for i in v[:12]: print('  ', i)
