import json, re, sys
from collections import defaultdict
RES, WT = sys.argv[1], sys.argv[2]
def norm(s):
    s = re.sub(r'[\r\n]*<br>', '\n', (s or '')).replace('\r', '\n')
    return '\n'.join(re.sub(r'\s+', ' ', l).strip() for l in s.split('\n')).strip()
camp_of = {'1': 'seoul', '2': 'sejong'}
fresh = {'seoul': defaultdict(list), 'sejong': defaultdict(list)}
qcount = defaultdict(int)
for line in open(RES):
    q = json.loads(line)
    c = camp_of[q['form']['pCampus']]
    qcount[c] += 1
    for r in q['rows']:
        fresh[c][(r['COUR_CD'], r['COUR_CLS'])].append((q, r))
out = {}
for c in ['seoul', 'sejong']:
    asset = json.load(open(f'{WT}/assets/timetable/korea-{c}-2026-2.json'))
    old = {(x['courseCode'], x['section']): x for x in asset['courses'] if x['courseCode']}
    F = fresh[c]
    rawrows = sum(len(v) for v in F.values())
    added = sorted(set(F) - set(old)); removed = sorted(set(old) - set(F))
    changed = []
    for k in sorted(set(F) & set(old)):
        o = old[k]; m = o.get('sourceEducationalMetadata', {})
        rows = [r for _, r in F[k]]; r = rows[0]
        diffs = {}
        if norm(r['TIME_ROOM']) != norm(o['sourceSchedule']): diffs['TIME_ROOM'] = [o['sourceSchedule'], r['TIME_ROOM']]
        if re.sub(r'(<br>|\s)', '', r['PROF_NM']) != re.sub(r'\s', '', o['professor']): diffs['PROF_NM'] = [o['professor'], r['PROF_NM']]
        if r['COUR_NM'] != o['courseName']: diffs['COUR_NM'] = [o['courseName'], r['COUR_NM']]
        if norm(r['APPLY_DEPT']) != norm(m.get('APPLY_DEPT', '')): diffs['APPLY_DEPT'] = [m.get('APPLY_DEPT', ''), r['APPLY_DEPT']]
        try:
            if float(r['CREDIT']) != float(o['credits'] or -1): diffs['CREDIT'] = [o['credits'], r['CREDIT']]
        except ValueError: diffs['CREDIT'] = [o['credits'], r['CREDIT']]
        for f in ['FLEXIBLE_FR_DT', 'FLEXIBLE_TO_DT', 'MOOC_YN', 'NEMO_YN']:
            if (r[f] or '') != (m.get(f) or '') and not (f.startswith('FLEX') is False and r[f] == '0' and not m.get(f)):
                diffs[f] = [m.get(f), r[f]]
        depts = sorted({r['DEPARTMENT'] for r in rows}); qdepts = sorted({q['label'].split('/')[-1] for q, _ in F[k]})
        if set(o['departments']) != set(depts) and set(o['departments']) != set(qdepts): diffs['DEPT'] = [o['departments'], depts, qdepts]
        if diffs: changed.append({'key': k, 'diffs': diffs})
    out[c] = {'queries': qcount[c], 'rawRows': rawrows, 'unique': len(F), 'assetCoded': len(old), 'added': added, 'removed': removed, 'changed': changed}
    print(c, 'queries', qcount[c], 'rows', rawrows, 'unique', len(F), 'asset', len(old), 'added', len(added), 'removed', len(removed), 'changed', len(changed))
json.dump(out, open(sys.argv[3], 'w'), ensure_ascii=False, indent=1, default=list)
