"""Two reviewed current plans: actual printed dates paired with displayed course clock."""
import json,re,datetime
from pathlib import Path
R=Path(__file__).resolve().parent
cat={c['COURSE_NO']:c for c in json.loads((R/'cnu-current-catalog-education.json').read_text())}
clock={c['courseId']:c for c in json.loads((R/'cnu-current-clock-projection.json').read_text())}
proofs=[]
for cid in ['1151-2003-01','1138-3006-00']:
 j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());meetings=[]
 byday={m['weekday']:m for m in clock[cid]['actualClockMeetings']}
 for w in j['weeks']:
  s=w.get('MAJ_LRN_CTNT') or ''
  # Explicit reviewed source layout: leading date list before &, or leading parentheses.
  lead=s.split('&',1)[0] if cid=='1151-2003-01' else re.match(r'^\(([^)]+)\)',s)[1]
  dates=re.findall(r'(?<!\d)(\d{1,2})[/.](\d{1,2})(?!\d)',lead)
  assert len(dates)==(2 if cid=='1151-2003-01' else 1)
  for month,day in dates:
   d=datetime.date(2026,int(month),int(day));wd=d.isoweekday();assert wd in byday
   m=byday[wd]
   exam=(cid=='1151-2003-01' and d.isoformat() in ['2026-10-20','2026-12-15']) or (cid=='1138-3006-00' and w['WKORD'] in [8,15])
   meetings.append({'date':d.isoformat(),'weekday':wd,'startMinute':m['startMinute'],'endMinute':m['endMinute'],'location':m['location'],'deliveryMode':'inPerson','sourceWeekLabel':w['WKORD'],'sessionKind':'exam' if exam else 'class','proofKind':'sourcePrintedDateWithCurrentCatalogClockAndRoom'})
 assert len(meetings)==(30 if cid=='1151-2003-01' else 15)
 assert len({m['date'] for m in meetings})==len(meetings)
 c=cat[cid]
 proofs.append({'verifiedOn':'2026-10-08','courseId':cid,'title':c['SBJT_NM'],'courseCode':c['OPEN_SBJT_NO'],'section':c['OPEN_DCLSS'],'nativeClassification':c['CPTN_DIV_CD_FNM'],'curriculumNativeClassification':c['CURI_CPTN_DIV_NM'],'department':c['OPEN_SUST_MJ_CD_NM'],'creditsOriginal':c['PNT_TMCNT'],'restrictionOriginal':c['TLSN_REST_INFO_CD_NM'],'remarksOriginal':c['TLSN_ANNM'],'originalTimetable':c['TMTBL_INFO'],'sourceResponseSHA256':j['sourceResponseSHA256'],'periodStart':min(m['date'] for m in meetings),'periodEnd':max(m['date'] for m in meetings),'meetings':meetings,'operatingReview':'Current teaching method and complete printed dates reviewed; generic disaster/remote contingency is not an actual switch','teachingDatesArePrinted':True,'clockAndRoomFromCurrentCatalog':True,'noHolidayDateOrWeekOrdinalExpansion':True,'wholeSchoolCompletionClaim':False})
(R/'cnu-additional-dated-proofs-20261008.json').write_text(json.dumps(proofs,ensure_ascii=False,indent=2));print('two courses45actual printed meetings')
