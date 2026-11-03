from pathlib import Path
import json,re,collections
p=Path(__file__).parent; pages=json.loads((p/'general-2026-2-native-tables.json').read_text());native=json.loads((p/'inje-native-all-public-rows.json').read_text());by=collections.defaultdict(list)
for r in native:by[(r['교과목'],r['분반'])].append(r)
records=[];classification=None;grade=None
for pg in pages:
 for ti,t in enumerate(pg['tables']):
  for ri,r in enumerate(t):
   if len(r)!=11:continue
   if r[1] in ['교선','교필','자선']:classification=r[1]
   if r[0] and str(r[0]).isdigit():grade=r[0]
   if not r[2] or not re.fullmatch('[A-Z]{3}\\d{3}',r[2]) or not r[4] or not r[4].isdigit():continue
   key=(r[2],r[4]);current=by.get(key,[]);base={'code':r[2],'section':r[4],'name':(r[3]or'').replace('\n',' '),'credits':r[5],'professor':r[8],'sourceSchedule':r[10],'sourceAudience':r[9],'sourceClassification':classification,'sourceGrade':grade,'sourcePage':pg['page'],'sourceTable':ti+1,'sourceRow':ri+1,'sourceUrl':'https://www.inje.ac.kr/kor/Board/Download.asp?pCode=PR040020000&key=5671','currentNativeRows':[v['sourceRow'] for v in current],'currentReportRegistered':any(v['reportOnclick'] for v in current),'applyEligible':False}
   diffs={}
   if current:
    for k,ck in [('credits','학점'),('professor','담당교수')]:
     value=' '.join((base[k]or'').split())
     vals=list(dict.fromkeys(v.get(ck)for v in current))
     if value and value not in vals:diffs[k]={'old':value,'current':vals}
   base['currentMetadataDifferences']=diffs
   base['status']='not-in-current-native' if not current else ('latest-report-available' if base['currentReportRegistered'] else ('old-pdf-current-metadata-conflict' if diffs else 'exact-current-native-no-report-time-supplement'))
   records.append(base)
(p/'inje-general-native-pdf-rows.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('pdfrows',len(records),'unique',len({(r['code'],r['section'])for r in records}),'status',collections.Counter(r['status']for r in records))
