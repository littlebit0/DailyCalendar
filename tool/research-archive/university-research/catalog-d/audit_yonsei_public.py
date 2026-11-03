"""Audit completed raw department collection without promoting activation status."""
from pathlib import Path
from collections import Counter, defaultdict
import json, re

p=Path(__file__).parent
d=json.loads((p/'yonsei-2026-2-public-all.json').read_text())
rows=d['records']
groups=defaultdict(list)
for row in rows:
    key=(row.get('sysinstDivCd'),row.get('subjtnb'),row.get('corseDvclsNo'),row.get('prctsCorseDvclsNo'))
    groups[key].append(row)
variants={}
for field in ['subjtNm','cgprfNm','lctreTimeNm','lecrmNm','cdt','campsDivNm','subsrtDivNm','atntnMattrDesc','rmvlcYn']:
    variants[field]=sum(len({json.dumps(r.get(field),ensure_ascii=False) for r in values})>1 for values in groups.values())
late=[{k:r.get(k) for k in ['subjtnbCorsePrcts','sysinstDivCd','campsDivNm','lctreTimeNm','lecrmNm','atntnMattrDesc']}
      for r in rows if any(int(x)>10 for x in re.findall(r'\d+',r.get('lctreTimeNm') or ''))]
stats=dict(scopes=len(d['scopes']),displayRows=len(rows),uniqueOfferingKeys=len(groups),capped=d['capped'],
           affiliations=dict(Counter(r.get('campsBusnsCd') for r in rows)),campuses=dict(Counter(r.get('campsDivNm') for r in rows)),
           sessions=dict(Counter(r.get('lessnSessnDivNm') for r in rows)),closedDisplayRows=sum(r.get('rmvlcYnNm')=='폐강' for r in rows),
           unscheduledDisplayRows=sum(not (r.get('lctreTimeNm') or '').strip() for r in rows),
           remarksDisplayRows=sum(bool(r.get('atntnMattrDesc')) for r in rows),fieldVariantsWithinOffering=variants,
           latePeriodDisplayRows=len(late),scopeCollectionFinished=True,productionActivationComplete=False)
requested=Counter()
for scope in d['scopes']:
    requested[scope['campus']]+=scope['count']
unique=[values[0] for values in groups.values()]
stats.update(requestedAffiliationDisplayRows=dict(requested),
             closedUniqueOfferings=sum(r.get('rmvlcYnNm')=='폐강' for r in unique),
             unscheduledUniqueOfferings=sum(not (r.get('lctreTimeNm') or '').strip() for r in unique),
             specialSessionUniqueOfferings=sum(r.get('lessnSessnDivNm')!='학기' for r in unique))
(p/'yonsei-2026-2-public-audit.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2))
(p/'yonsei-2026-2-late-period-audit.json').write_text(json.dumps(late,ensure_ascii=False,indent=2))
print(json.dumps(stats,ensure_ascii=False))
