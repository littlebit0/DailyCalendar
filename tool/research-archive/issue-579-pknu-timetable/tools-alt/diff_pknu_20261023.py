"""10/23 직접 조회 결과와 PR #591 자산의 강의계획서 필드를 비교한다(자산은 바꾸지 않음)."""
import json, sys
from pathlib import Path

alt = Path(sys.argv[1]); assets = [Path(p) for p in sys.argv[2:]]
asset = {}
for f in assets:
    for c in json.loads(f.read_text())['courses']:
        asset[c['courseCode'] + '-' + c['section']] = c
rows = {r['COURSE_NO'] + '-' + r['DCLSS_NO']: r for r in json.loads((alt / 'latest-rows.json').read_text())}
keys = ['교과목명', '강의시간', '강의실', '강의형태', '개설학년', '학점-이론-실습']
out = {'fetched': 0, 'errors': [], 'unavailable': [], 'changed': [], 'evidenceChanged': [], 'clockUnit': [], 'pending': 0}
for ident, r in rows.items():
    f = alt / 'syllabus' / (ident + '.json')
    if (alt / 'syllabus' / (ident + '.error.json')).exists() and not f.exists():
        out['errors'].append(ident); continue
    if not f.exists():
        out['pending'] += 1; continue
    s = json.loads(f.read_text()); a = asset[ident]
    if s.get('unavailable'):
        out['unavailable'].append({'identity': ident, 'assetStatus': a['scheduleStatus'], 'assetHadPlan': bool(a['publicPlanEducation'].get('verifiedAt'))}); continue
    out['fetched'] += 1
    old = a['publicPlanEducation'].get('fields', {})
    d = {k: [old.get(k), s['fields'].get(k)] for k in keys if (old.get(k) or '') != (s['fields'].get(k) or '')}
    if d:
        out['changed'].append({'identity': ident, 'status': a['scheduleStatus'], 'diff': d})
    oe = a['publicPlanEducation'].get('periodRestrictionEvidence', []); ne = s.get('periodRestrictionEvidence', [])
    if oe != ne:
        out['evidenceChanged'].append({'identity': ident, 'status': a['scheduleStatus'], 'old': oe, 'new': ne})
    if s.get('clockUnitEvidence'):
        out['clockUnit'].append({'identity': ident, 'status': a['scheduleStatus'], 'time': s['fields'].get('강의시간'), 'lines': s['clockUnitEvidence']})
print(json.dumps({k: (len(v) if isinstance(v, list) else v) for k, v in out.items()}, ensure_ascii=False))
(alt / 'diff-vs-pr591.json').write_text(json.dumps(out, ensure_ascii=False, indent=1))
