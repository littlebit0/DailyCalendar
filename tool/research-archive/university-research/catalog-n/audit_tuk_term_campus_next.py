"""Normal public rule/calendar reads; preserve only education clauses and hashes."""
import hashlib,html,json,re,urllib.request
from pathlib import Path
P=Path(__file__).parent
sources={}
def read(url):
 b=urllib.request.urlopen(url,timeout=30).read();s=b.decode('utf-8');s=re.sub(r'<(?:script|style)\b.*?</(?:script|style)>','',s,flags=re.S|re.I)
 t=html.unescape(re.sub('<[^>]+>',' ',s));t=re.sub(r'\s+',' ',t)
 sources[url]={'responseSHA256':hashlib.sha256(b).hexdigest()};return t
rule='https://rule.tukorea.ac.kr/lmxsrv/law/lawFullContent.do?SEQ=31&SEQ_HISTORY=1893'
t=read(rule)
clauses={}
for a,b in [(7,8),(8,9),(9,10)]:
 x=t.index(f'제 {a} 조');y=t.index(f'제 {b} 조',x+1);clauses[str(a)]=t[x:y].strip()
assert '공휴일' in clauses['9'] and '휴업일이라도' in clauses['9']
calendar='https://www.tukorea.ac.kr/haksa/3000/subview.do';t=read(calendar)
terms={}
for word in ['2학기 개강','2학기 중간고사','2학기 기말고사','2학기 보강주','개교기념일(29주년)','동계방학 시작']:
 i=t.index(word);terms[word]=t[max(0,i-55):i+80]
mapfile=P/'tuk-2026-contract-public-guide.pdf';maptext=(P/'tuk-2026-campus-map-extract.txt').read_text()
audit={'captureDate':'2026-10-08','researchOnly':True,'completionClaim':False,'normalPublicRulesPath':['https://www.tukorea.ac.kr/tukorea/1072/subview.do','https://rule.tukorea.ac.kr/','/lmxsrv/main/main.do','published lmx_tree.js/lmx_const.js','lawTreeNodes LAWGROUP1/PARENT1→4→10','lawFullView SEQ31 current history1893',rule],'currentRuleHistory':1893,'currentRuleRevision':'2026-09-01','educationClauses':clauses,'calendarEducationSnippets':terms,'officialSemesterPeriod':{'startDate':'2026-09-01','endDate':'2026-12-22'},'ordinaryPublishedPlanScope':{'startDate':'2026-09-01','endDate':'2026-12-07','excludedMidtermStart':'2026-10-20','excludedMidtermEnd':'2026-10-26'},'examScope':'2026-12-08~12-21; no invented exam appointment','makeupScope':'2026-12-15~12-22; actual makeups unconfirmed, not generated','publicHolidayPrimaryURL':'https://astro.kasi.re.kr/kor/life/post/calendarData?search_year=2026','excludedPublicHolidayDates':['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'],'holidayRuleException':'Article9(3) permits separately specified holiday classes/labs; no exact class exception inferred','sources':sources,'campusProof':{'sourceUrl':'https://tukorea.ac.kr/sites/contract/contents/files/2026_contract.pdf','sourceSHA256':hashlib.sha256(mapfile.read_bytes()).hexdigest(),'pdfPage':2,'previousVisualVerified':True,'actualCampusName':'제1캠퍼스','actualBuildingNames':['공학관A동','공학관B동','공학관C동','공학관D동','공학관E동','공학관G동','공학관P동','기술혁신파크(TIP생활관)','체육관'],'mappedExactRoomPatterns':['^[ABCDEGP]동','^TIP','^체육관$'],'uncertainAliasesPreservedUnknown':['산융','중앙','비즈','교수연구실','미배정','온라인강좌'],'sourceCampusExplicit':None,'derivedCampusNotNativePublication':True},'limitations':['July15 identity/slot snapshot; Sep8 observed36 closures; no whole final-active claim','Company/industry tables without actual offering code/section remain separate pending','Current8/27 computer grid cannot be nativecode joined by title alone','Regular published reservations, not individual actual attendance']}
out=P/'tuk-current-term-campus-proof-next-20261008.json';assert not out.exists();out.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print({'proof':out.name,'ruleRevision':audit['currentRuleRevision'],'semester':audit['officialSemesterPeriod']})
