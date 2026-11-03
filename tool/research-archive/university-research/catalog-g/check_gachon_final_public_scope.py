"""Fresh post-audit current public scope check; no internal identity is retained."""
import json,time,collections
from pathlib import Path
from datetime import datetime,timezone
from audit_gachon_full_operating_reports import request,HEAD,HOST,PUBLIC
P=Path(__file__).resolve().parent
reports=json.loads((P/'gachon-full-operating-report-audit.json').read_text())
old={(r['campus'],r['sourceRow']['HAKSU_NO']):r['sourceRow'] for r in reports['reports']}
result={'researchOnly':True,'completionClaim':False,'allCurrentParser6ReportsFetched':reports['allCurrentReportsFetched'] and sum(r.get('educationalParserVersion',0)>=6 for r in reports['reports'])==3809,'queries':[],'scopeStable':False}
if not result['allCurrentParser6ReportsFetched']:
    raise SystemExit('Whole current parser6 report audit is still incomplete; final live-scope proof not claimed.')
new={}
try:
    for campus in ('20','21'):
        for category in ('001','002','003','004','005','006'):
            query={'groupType':campus,'searchYear':'2026','searchTerm':'20','searchUnivCD':'','searchDeptCD':'','searchIsuCD':category,'searchGrade':'','searchSubjectNm':''}
            body=request(HOST+'/Ssu1000q/mainSearch.do',json.dumps({'data':{'SendData':query}}).encode(),{**HEAD,'Content-Type':'application/json;charset=UTF-8','Referer':HOST+'/ssu/showTimetable.do'})
            parsed=json.loads(body);rows=parsed.get('MainData');count=int(parsed['dmRowCnt']['rowCnt'])
            if not isinstance(rows,list) or len(rows)!=count:raise RuntimeError('Incomplete actual scope')
            result['queries'].append({'campus':campus,'category':category,'rowCount':count})
            for row in rows:
                key=(campus,row['HAKSU_NO'])
                if key in new:raise RuntimeError('Duplicate current offering identity')
                new[key]={k:row.get(k) for k in PUBLIC}
            body=None;parsed=None;rows=None;time.sleep(.8)
    result['currentCount']=len(new)
    result['added']=[{'campus':k[0],'offeringCode':k[1]} for k in sorted(new.keys()-old.keys())]
    result['removed']=[{'campus':k[0],'offeringCode':k[1]} for k in sorted(old.keys()-new.keys())]
    result['changed']=[{'campus':k[0],'offeringCode':k[1],'educationalFields':[f for f in PUBLIC if old[k].get(f)!=new[k].get(f)]} for k in sorted(old.keys()&new.keys()) if any(old[k].get(f)!=new[k].get(f) for f in PUBLIC)]
    result['scopeStable']=len(new)==3809 and not result['added'] and not result['removed'] and not result['changed']
except BaseException as error:
    result['stopped']=True;result['failureType']=type(error).__name__;result['failure']='Normal current public request failed; no bypass or private exception text.'
result['checkedAt']=datetime.now(timezone.utc).isoformat()
temporary=P/'gachon-final-current-scope-check.tmp';temporary.write_text(json.dumps(result,ensure_ascii=False,indent=2));temporary.replace(P/'gachon-final-current-scope-check.json')
print({k:result.get(k) for k in ('currentCount','scopeStable','stopped')})
