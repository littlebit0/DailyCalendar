import json,collections,hashlib
from pathlib import Path
from parse_mirae_education_groups import parse
p=Path(__file__).parent
old=Path('work/university-research/catalog-w/yonsei')
f=old/'yonsei-mirae-2026-2.published-partial-v1.json'
d=json.loads(f.read_text());a=json.loads((old/'candidate-audit-v1.json').read_text())
held={h['identity']:h['reason'] for h in a['holds']}
rows=[]
for c in d['courses']:
    if c['schedules']:continue
    r=c['sourceEducation'][0];identity='/'.join([r['sysinstDivCd'],r['subjtnb'],r['corseDvclsNo'],r['prctsCorseDvclsNo']])
    if held[identity]!='공개 수업시간 표기의 의미를 확인해야 합니다.':continue
    assert r['sysinstDivCd']=='H2' and r['campsDivNm']=='미래' and r['lessnSessnDivNm']=='학기'
    row={'sourceId':c['sourceId'],'nativeIdentity':identity,'sourceSchedule':c['sourceSchedule'],'sourceClassroom':c['sourceClassroom'],'nativePracticumSection':c['nativePracticumSection'],'nativeDepartmentAliases':c['departments'],'sourceAliasCount':len(c['sourceEducation']),'sourceLegendVerified':False}
    try:row['nativeSlots']=parse(c['sourceSchedule'],c['sourceClassroom']);row['parseResult']='exact structurally paired education groups; awaiting official legend proof'
    except ValueError as e:row['parseResult']=str(e)
    rows.append(row)
assert len(rows)==362
out={'researchOnly':True,'completionClaim':False,'originalMiraeSha256':hashlib.sha256(f.read_bytes()).hexdigest(),'poolCount':362,'sourceLegendVerified':False,'scheduledCandidateGenerated':False,'parseResultCounts':dict(collections.Counter(r['parseResult'] for r in rows)),'reviewRows':rows}
(p/'prior-mirae-parenthesis-structural-review.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(out['parseResultCounts'])
