from pathlib import Path
import pdfplumber,json,hashlib,re
ROOT=Path(__file__).parent
urls={'first':'https://politics.korea.ac.kr/kupolitics_kor/community/under_school.do?articleNo=1583137&attachNo=321078&mode=download&totalBoardNo=&totalNoticeYn=','second':'https://hoan.korea.ac.kr/hoan/commu/notice.do?mode=download&articleNo=1584654&attachNo=322027&totalNoticeYn=&totalBoardNo='}
allsets={};receipts=[]
for phase,limit,count,date in [('first',1,18,'2026-08-26'),('second',3,114,'2026-09-10')]:
 src=Path('/private/tmp/daily-ku-'+phase+'-closure2026-2.pdf');native=[];english=[]
 with pdfplumber.open(src) as pdf:
  for i,page in enumerate(pdf.pages):
   tables=page.extract_tables();assert len(tables)==1
   rows=tables[0];header=rows[0]
   for row in rows[1:]:
    if phase=='first':code,section=row[7:9]
    else:code,section=row[6:8]
    assert re.fullmatch('[A-Z]{4}[0-9]{3}',code) and re.fullmatch('[0-9]{2}',section)
    rec={'sourcePage':i+1,'sourceNumber':row[0],'sourceHeader':header,'sourceEducationalCells':row,'nativeCode':code,'nativeSection':section,'identity':code+'-'+section,'scope':'Seoul','sourcePhase':phase}
    (native if i<limit else english).append(rec)
 assert len(native)==count and len(english)==count
 assert {r['identity'] for r in native}=={r['identity'] for r in english}
 assert len({r['identity'] for r in native})==count
 allsets[phase]={r['identity'] for r in native}
 receipt={'researchOnly':True,'sourceDate':date,'sourceUrl':urls[phase],'normalPublicDownloadStatus':200,'sourceSHA256':hashlib.sha256(src.read_bytes()).hexdigest(),'scope':'Current2026-2 Seoul undergraduate cancellations, not Sejong','nativeCancelledOfferings':count,'englishIdentityIndependentMatch':True,'rows':native,'englishRows':english,'privateIdentifiersContactsCollected':False};(ROOT/(phase+'-closure-native-educational-receipt.json')).write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');receipts.append({'phase':phase,'count':count,'sha256':receipt['sourceSHA256']})
a={'researchOnly':True,'currentWholeClosureComplete':False,'sourcePhaseCounts':receipts,'firstSecondIdentityIntersection':sorted(allsets['first']&allsets['second']),'knownSeoulClosedUnionCount':len(allsets['first']|allsets['second']),'knownSeoulClosedUnion':sorted(allsets['first']|allsets['second']),'thirdRoundDateKnown':'2026-09-23','thirdRoundNativeListObtained':False,'SejongNativeClosureListObtained':False,'closureJoinRule':'exact observed campus Seoul + code + section; never title-only or Sejong codeborrow. Latest current publicquery contradictions need explicit sourceprecedence audit.'};(ROOT/'closure-cumulative-scope-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(a['knownSeoulClosedUnionCount'],a['firstSecondIdentityIntersection'])
