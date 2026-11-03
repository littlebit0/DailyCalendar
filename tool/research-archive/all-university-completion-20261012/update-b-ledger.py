import json
from pathlib import Path
O=Path('work/all-university-completion-20261012');p=O/'program-groups-b.json';x=json.load(open(p))
root_scope={k for k in x['scope']if 'bnue'<=k<='hknu'}-{'cnu'}
agent_a_scope={'gachon','cau','chosun','daegu','dku','donga','gnu','hansung'}
finished_program_comparison={'kmu','knu','korea','khu','jeju','kookmin','kyonggi','inu','jnu','dku','cau','catholic','hansung','kangnam','hufs','cnu','pnu','hoseo','ajou','gnu','kangwon','kunsan','hongik','mju','iccu','kumoh','pcu','nsu','hyupsung','kwangwoon','kau','kaist','kmou','koreatech','pknu','jbnu','mmu','konkuk','baekseok','mokpo','inha','knue','kongju'}
issues={
 'jnu':{'department':'디지털경제융합전공','reason':'현재 공식시간표/도서관은 HUSS여수 소속으로 표기, 타 참여대학 공개HUSS교류원문에 정확한 과정명이 있으나 전남 원문 제도목록을 아직 확보하지 못함. 디지털경제 마이크로디그리의 참여과정이라는 이유로 MD분류하지 않음.','researchComplete':False},
 'jnue':{'department':None,'reason':'현재 organization mappings0. 공식전공제도 source조사 미완료이며 실질학과sourceLabel이0인 이유 별도 전체시간표지원감사와 연결 필요.','researchComplete':False},
 'inje':{'department':None,'reason':'현재 organization 단일행 department null. 현재제도목록을 확보하는 조사 남음; 개별학과 이름을 알 수 없는 course source scope 추가감사 필요.','researchComplete':False}}
coverage=[];remaining=[]
for k in sorted(x['scope']):
 org=json.load(open('assets/timetable/organizations/'+k+'.json'));rows=org['mappings'];own=[e for e in x['entries']if e['university']==k]
 checked=x['checkedSources'].get(k,[])
 reused=[{'url':e.get('sourceUrl'),'sourceFile':e.get('sourceFile')}for e in own if e['kind']!='officialProgramSystem']
 urls=list(dict.fromkeys(s['url']for s in checked if s.get('url')))
 coverage.append({'university':k,'owner':'A'if k in agent_a_scope else 'root'if k in root_scope else'B','nativeRows':len(rows),'sourceCorrectionRows':len(own),'programCorrectionRows':sum(e['kind']=='officialProgramSystem'for e in own),'programSources':checked,'ordinaryEvidenceReused':reused,'programComparisonPerformed':k in finished_program_comparison,'programResearchComplete':k in finished_program_comparison and k not in issues,'researchComplete':False,'remaining':[issues[k]]if k in issues else[],'parentScopePending':k in root_scope or k in agent_a_scope})
 if k in issues:remaining.append({'university':k,**issues[k],'checkedSources':urls})
 # Record uncorrected explicit 'unverified' labels separately; direct real units do not need invented colleges.
 handled={(e['campus'],e['sourceLabel'])for e in own}
 for m in rows:
  if m.get('college')is not None or (m.get('campus','*'),m['sourceLabel'])in handled:continue
  if not any(token in m.get('evidence','').lower() for token in ('unverified','unconfirmed')):continue
  remaining.append({'university':k,'campus':m.get('campus','*'),'sourceLabel':m['sourceLabel'],'department':m.get('department'),'kind':'ordinaryAffiliationPending','researchComplete':False,'reason':'공식 일반학사조직 exact alias 또는 native영문/legacy명 직접대조 미완료. null은 소속없음이라는 완료주장이 아님.','checkedSources':urls,'owner':'A'if k in agent_a_scope else 'root'if k in root_scope else'B'})
x['unresolved']=remaining;x['schoolCoverage']=coverage;x['final']=False
p.write_text(json.dumps(x,ensure_ascii=False,indent=2));(O/'school-coverage-b.json').write_text(json.dumps({'final':False,'schoolCoverage':coverage,'unresolved':remaining},ensure_ascii=False,indent=2))
print('source rows',len(x['entries']),'schools',len(coverage),'pending program issues',len(issues),'pending total rows',len(remaining))
