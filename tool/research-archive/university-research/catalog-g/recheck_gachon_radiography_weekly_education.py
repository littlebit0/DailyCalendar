"""Current narrowly scoped public educational weekly table, no raw PDF/identifiers retained."""
import json
import time
from pathlib import Path
import recheck_gachon_career_weekly_education as edu
mod=edu.mod
ROOT=Path(__file__).resolve().parent
CODES=set('M3836001 M3836002 M3837001 M3837002 M3838001 M3838002 M3839001 M3839002 M3511001'.split())
def main():
 mod.parse_report=edu.education_parser
 originals={r['sourceRow']['HAKSU_NO']:r for r in json.loads((ROOT/'gachon-full-operating-report-audit.json').read_text())['reports'] if r['campus']=='21'}
 previous={c:r['sourceRow'] for c,r in originals.items()}
 names=sorted({(originals[c]['category'],previous[c]['SUBJECT_NM_KOR'].split('(')[0].strip()) for c in CODES})
 items={};proofs=[]
 for category,name in names:
  query={'groupType':'21','searchYear':'2026','searchTerm':'20','searchUnivCD':'','searchDeptCD':'','searchIsuCD':category,'searchGrade':'','searchSubjectNm':name}
  response=mod.request(mod.HOST+'/Ssu1000q/mainSearch.do',json.dumps({'data':{'SendData':query}}).encode(),{**mod.HEAD,'Content-Type':'application/json;charset=UTF-8','Referer':mod.HOST+'/ssu/showTimetable.do'})
  parsed=json.loads(response);rows=parsed.get('MainData');assert isinstance(rows,list) and len(rows)==int(parsed['dmRowCnt']['rowCnt'])
  proofs.append({'campus':'21','publishedSubjectNameSearch':name,'sourceCategory':category,'returnedCount':len(rows)})
  for row in rows:
   code=row['HAKSU_NO']
   if code in CODES:
    assert all(row.get(k)==previous[code].get(k) for k in mod.PUBLIC)
    items[code]=row
  del rows,parsed,response
  time.sleep(1)
 if set(items)!=CODES:
  (ROOT/'gachon-radiography-public-query-scope-mismatch-20261008.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'publishedQueryProofs':proofs,'foundOfferingCodes':sorted(items),'missingOfferingCodes':sorted(CODES-set(items)),'rawReportFetched':False,'limitation':'Normal course-name query scope mismatch; not a protection or school impossibility claim.'},ensure_ascii=False,indent=2)+'\n')
  raise RuntimeError('Normal public query scope mismatch; recorded education-only proof; stop')
 out=ROOT/'gachon-radiography9-current-weekly-education-recheck-20261008.json';assert not out.exists()
 result={'researchOnly':True,'completionClaim':False,'expectedCount':9,'source':'Existing observed normal public ReportingServer export via current official public course identifiers; no account login','rawReportPersisted':False,'personalIdentifierPersisted':False,'rows':[],'stopped':False,'freshNarrowPublicQueries':proofs,'internalReportIdentifierHandling':'Transient current published form response only, never stored or output'}
 try:
  for code,row in items.items():
   started=time.monotonic();record=mod.fetch_report(('21',originals[code]['category'],row))
   if code not in edu.captured:raise RuntimeError('Current public report not returned; stop')
   result['rows'].append({'campus':'21','offering':code,'title':row['SUBJECT_NM_KOR'],**edu.captured.pop(code)})
   del record
   out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
   time.sleep(max(0,1-(time.monotonic()-started)))
 except Exception as e:
  result['stopped']=True;result['failureType']=type(e).__name__;out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');raise RuntimeError('Normal public recheck stopped, no bypass/retries') from None
 print(json.dumps({'educationReportsRead':len(result['rows']),'complete':len(result['rows'])==9}))
if __name__=='__main__':main()
