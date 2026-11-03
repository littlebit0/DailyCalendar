"""Compare actual current educational detail with source clocks, no network or IDs."""
import re,json,collections
from pathlib import Path
P=Path(__file__).resolve().parent
CLOCK=re.compile(r'([월화수목금토일])(?:\[[^\]]*\])?(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')
def frames(value):return [(m[1],int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5])) for m in CLOCK.finditer(value)]
a=json.loads((P/'skku-public-operating-plan-audit.json').read_text());counts=collections.Counter();records=[]
for r in a['records']:
 s=r['sourceRow'];d=r['detail'][0] if r['detail'] else None;raw=frames(s['GYOSI_NAME']);detail=frames(d.get('SUUP_YOIL_GYOSI','')) if d else []
 if not d:status='currentDetailMissing'
 elif raw and detail and sorted(raw)!=sorted(detail):status='actualCurrentDetailClockConflict'
 elif raw and not detail:status='currentDetailClockUnrecognized'
 elif not raw and detail:status='sourceClockUnrecognizedButCurrentDetailClockPresent'
 elif raw:status='actualCurrentClockMatch'
 else:status='noClockInEitherSource'
 counts[status]+=1
 teacher_match=bool(d) and d['PER_NAME'].strip()==s['PER_NAME'].strip()
 records.append({'offeringCode':r['offeringCode'],'status':status,'sourceClockFrames':raw,'actualDetailClockFrames':detail,'catalogTeacherMatchesCurrentDetail':teacher_match,'sourcePrintedRoom':s['GYOSI_NAME'],'actualDetailPrintedRoom':d.get('SUUP_GANGUISIL','') if d else '', 'currentIdentityConfirmed':r['currentDetailIdentityConfirmed']})
result={'researchOnly':True,'productionActivationAllowed':False,'completionClaim':False,'allCurrentDetailsFetched':a['allCurrentDetailsFetched'],'count':a['count'],'counts':dict(counts),'teacherMismatchCount':sum(not r['catalogTeacherMatchesCurrentDetail'] for r in records),'records':records}
(P/'skku-current-detail-clock-comparison.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print({k:v for k,v in result.items() if k!='records'})
