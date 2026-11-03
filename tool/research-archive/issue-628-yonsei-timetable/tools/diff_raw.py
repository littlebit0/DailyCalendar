"""2026-10-07 원자료와 2026-10-23 재조회를 강좌(소속기관/학정번호/분반/실습분반) 단위로 대조."""
import json, sys, collections
from pathlib import Path
OLD = Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-d/yonsei-2026-2-public-all.json')
NEW = Path(sys.argv[1])
FIELDS = ['sysinstDivCd','orgSysinstDivCd','campsBusnsCd','campsDivNm','subjtnb','corseDvclsNo','prctsCorseDvclsNo','subjtnbCorsePrcts','subjtNm','subjtEngNm','cgprfNm','cgprfEngNm','cdt','hy','rcognHrs','subsrtDivNm','estblDeprtNm','subjtClNm','srclnLctreLangDivNm','lctreTimeNm','lecrmNm','atntnMattrDesc','lessnSessnDivNm','rmvlcYn','rmvlcYnNm','syy','smtDivCd']
old = json.loads(OLD.read_text())
scopes = json.loads((NEW/'scopes.json').read_text())
newrows = []
for s in scopes:
    newrows += json.loads((NEW/f"{s['campus']}-{s['collegeCode']}-{s['departmentCode'] or 'all'}.json").read_text())['dsSles251']
def key(r): return (r['sysinstDivCd'], r['subjtnb'], r['corseDvclsNo'], r['prctsCorseDvclsNo'])
def group(rows):
    g = collections.defaultdict(list)
    for r in rows: g[key(r)].append({k: r.get(k) for k in FIELDS})
    return g
go, gn = group(old['records']), group(newrows)
oscope = {(s['campus'], s['collegeCode'], s['departmentCode']) for s in old['scopes']}
nscope = {(s['campus'], s['collegeCode'], s['departmentCode']) for s in scopes}
print('scopes old/new', len(oscope), len(nscope), 'added', sorted(nscope-oscope), 'removed', sorted(oscope-nscope))
print('capped', sum(s['capped'] for s in scopes), 'rows old/new', len(old['records']), len(newrows))
print('keys old/new', len(go), len(gn))
openo = {k for k, v in go.items() if v[0]['rmvlcYn'] != '1'}
openn = {k for k, v in gn.items() if v[0]['rmvlcYn'] != '1'}
print('open old/new', len(openo), len(openn))
added = sorted(openn - openo); removed = sorted(openo - openn)
changed = collections.defaultdict(list)
for k in sorted(openo & openn):
    a, b = go[k], gn[k]
    if a == b: continue
    sa = {json.dumps(x, ensure_ascii=False, sort_keys=True) for x in a}; sb = {json.dumps(x, ensure_ascii=False, sort_keys=True) for x in b}
    if sa == sb: changed['order_only'].append(k); continue
    fs = set()
    if len(a) != len(b): fs.add('rows')
    for f in FIELDS:
        if {json.dumps(x.get(f), ensure_ascii=False) for x in a} != {json.dumps(x.get(f), ensure_ascii=False) for x in b}: fs.add(f)
    changed[','.join(sorted(fs))].append(k)
print('added', len(added), 'removed(closed or gone)', len(removed))
for k in added: print(' +', k, gn[k][0]['subjtNm'], gn[k][0]['lctreTimeNm'], gn[k][0]['lecrmNm'], gn[k][0]['campsDivNm'])
for k in removed: print(' -', k, go[k][0]['subjtNm'], 'closedNow' if k in gn else 'absent')
for f, ks in sorted(changed.items(), key=lambda x: -len(x[1])): print(' ~', f, len(ks), ks[:5])
json.dump(dict(added=added, removed=removed, changed={f: ks for f, ks in changed.items()}), open(NEW.parent/'tools'/'diff-20261023.json', 'w'), ensure_ascii=False, indent=1)
