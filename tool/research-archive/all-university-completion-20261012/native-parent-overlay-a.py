import json,collections
from pathlib import Path
p=Path(__file__).parent;src=p/'root-followup-a-sources';f=p/'program-groups-root-followup-a.json';j=json.loads(f.read_text());rows=json.loads((src/'gachon-native-parent-receipts.json').read_text());ix=collections.defaultdict(list)
for r in rows:
 for d in r.get('departments',[]):
  if '(폐기)' not in r['college']['LABEL'] and '(폐기)' not in d['LABEL']:ix[d['LABEL']].append((r,d))
asset=json.loads(Path('assets/timetable/organizations/gachon.json').read_text());done={(e['university'],e['department'],e['sourceLabel']) for e in j['entries']}
for m in asset['mappings']:
 d=m.get('department');hits=ix.get(d,[]);parents={r['college']['LABEL'] for r,n in hits}
 if m.get('college') is None and len(parents)==1:
  r,n=hits[0];c=next(iter(parents));k=('gachon',d,m['sourceLabel'])
  if k in done:continue
  iscollege=('대학' in c or '칼리지' in c) and not c.endswith('사업단')
  e=dict(university='gachon',department=d,college=c if iscollege else None,campus=m.get('campus','*'),sourceLabel=m['sourceLabel'],sourceUrl='https://info.gachon.ac.kr/ssu/showTimetable.do',sourceFile=r['sourceFile'],evidence='2026-2 공개 시간표의 실제 대학→학부/학과 콤보. onLoad cbUnivCD 대학 '+r['college']['LABEL']+'('+r['college']['VALUE']+') 선택 후 deptList cbDeptCD exact LABEL '+d+' / DPT_CD '+n['DPT_CD']+' / UNIV_CD '+n['UNIV_CD']+'. 폐기 대학/폐기 학과 제외 후 동일 이름의 부모가 하나이며 기존 부서명 보존. 원래 개설조직과 대학별 콤보 관계를 연결; 이름유사 추측 아님.',kind='college' if iscollege else 'universityDirect')
  if not iscollege:e['group']=c
  j['entries'].append(e);done.add(k)
# B already has ordinary exact original names from same current rule; reuse rather than duplicate.
b=json.loads((p/'program-groups-b.json').read_text());bk={(e['university'],e['department'],e.get('sourceLabel'))for e in b['entries']}
j['entries']=[e for e in j['entries']if not(e['university']=='hansung' and (e['university'],e['department'],e['sourceLabel'])in bk)]
resolved={(e['university'],e['department'])for e in j['entries']}|{(e['university'],e['department'])for e in b['entries']}
j['unresolved']=[x for x in j['unresolved']if(x['university'],x['department'])not in resolved]
j['nativeGachonAudit']={'collegeQueries':len(rows),'failedQueries':sum('error'in r for r in rows),'publishedDepartmentRows':sum(len(r.get('departments',[]))for r in rows),'multipleActiveParents':[{'department':d,'parents':sorted({r['college']['LABEL']for r,n in ix[d]})}for d in sorted({m['department']for m in asset['mappings']if m.get('college')is None})if len({r['college']['LABEL']for r,n in ix[d]})>1]}
f.write_text(json.dumps(j,ensure_ascii=False,indent=2));print('candidate',len(j['entries']),'unknown',len(j['unresolved']),j['nativeGachonAudit']['multipleActiveParents'])
