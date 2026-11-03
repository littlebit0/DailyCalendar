import json, os, sys, glob, collections
OUT, ASSET = sys.argv[1], sys.argv[2]
m = json.load(open(os.path.join(OUT, 'manifest.json')))
def rows(v):
    if not isinstance(v, dict): return []
    r = v.get('row', []); return r if isinstance(r, list) else [r]
today = {}   # REF_KEY -> {queryKey: row}
base_rows = 0; c2keys = set(); allc2 = None
for q in m['queries']:
    name = f"list-{q['div']}-{q['department'] or 'all'}-{q['code2'] or 'all'}"
    res = json.load(open(os.path.join(OUT, 'raw', name + '.json')))['root']
    lst = rows(res.get('openSubList'))
    if q['code2']:
        c2keys |= {r['REF_KEY'] for r in lst}; continue
    base_rows += len(lst)
    for r in lst:
        today.setdefault(r['REF_KEY'], {})[(q['div'], q['department'])] = r
    if q['div'] == 'CCR00112': allc2 = {r['REF_KEY'] for r in lst}
print('base queries', sum(1 for q in m['queries'] if not q['code2']), 'rows', base_rows, 'unique', len(today))
print('code2 subset of 교양선택 all:', c2keys <= allc2, len(c2keys), len(allc2), 'missing in all:', len(c2keys - allc2))
print('errors', [q for q in m['queries'] if q['err']][:3])
a = json.load(open(ASSET))
old = {}
for c in a['courses']:
    for s in c.get('publicEducationBySelection', []):
        old.setdefault(s['education']['REF_KEY'], {})[(s['query']['div'], s['query']['department'])] = s['education']
oldrows = sum(len(v) for v in old.values())
print('asset courses', len(a['courses']), 'asset refkeys', len(old), 'asset rows', oldrows)
added = sorted(set(today) - set(old)); removed = sorted(set(old) - set(today))
print('added', len(added), 'removed', len(removed))
def brief(r): return f"{r['SB_CD']}-{r['DIVCLS_CD']} {r['SB_CD_NM']} {r['PROF_NM']} [{r['CLASS']!r}]"
for k in added: print(' +', k, brief(next(iter(today[k].values()))))
for k in removed: print(' -', k, brief(next(iter(old[k].values()))))
# field diffs on common
diffs = collections.Counter(); ex = collections.defaultdict(list); seldiff = []
for k in set(today) & set(old):
    if set(today[k]) != set(old[k]): seldiff.append((k, sorted(set(today[k]) ^ set(old[k]))))
    for qk in set(today[k]) & set(old[k]):
        t, o = today[k][qk], old[k][qk]
        for f in sorted(set(t) | set(o)):
            if t.get(f) != o.get(f):
                diffs[f] += 1
                if len(ex[f]) < 6: ex[f].append((k, qk, o.get(f), t.get(f)))
print('selection membership diffs', len(seldiff)); [print('  ', s) for s in seldiff[:30]]
print('field diffs', dict(diffs))
for f, e in ex.items():
    print('##', f)
    for x in e: print('  ', x)
print('today fields', sorted(next(iter(next(iter(today.values())).values())).keys()))
