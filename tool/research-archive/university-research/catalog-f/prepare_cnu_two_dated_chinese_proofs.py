"""Two reviewed full printed-date plans; makeup room remains individually unknown."""
import json,re,datetime
from pathlib import Path
R=Path(__file__).resolve().parent
cat={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education.json').read_text())}
clocks={r['courseId']:r for r in json.loads((R/'cnu-current-clock-projection.json').read_text())}
DATE=re.compile(r'(?<!\d)(\d{1,2})/(\d{1,2})\s*\(([월화수목금토일])\)')
result=[]
for cid in ['1105-3022-00','1105-4009-00']:
 j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());meetings=[];closures=[];evidence=[]
 original={m['weekday']:m for m in clocks[cid]['actualClockMeetings']}
 for w in j['weeks']:
  text=w.get('MAJ_LRN_CTNT') or '';dates=list(DATE.finditer(text))
  for i,m in enumerate(dates):
   d=datetime.date(2026,int(m[1]),int(m[2]));wd='월화수목금토일'.index(m[3])+1;assert d.isoweekday()==wd
   segment=text[m.end():dates[i+1].start() if i+1<len(dates) else len(text)]
   if '휴강' in segment:
    closures.append({'date':d.isoformat(),'sourceWeek':w['WKORD'],'reason':'official current plan explicitly no class'});continue
   makeup=d.isoformat() in ('2026-12-09','2026-12-11')
   if makeup:
    note='\n'.join(q.get('ETC_CTNT','') for q in j['weeks'])
    pat=rf'{int(m[1])}/{int(m[2])}\s*\({m[3]}\)\s*(\d{{1,2}}):(\d{{2}})~(\d{{1,2}}):(\d{{2}})'
    a=re.search(pat,note);assert a
    start=int(a[1])*60+int(a[2]);end=int(a[3])*60+int(a[4]);room=None
   else:
    assert wd in original;start=original[wd]['startMinute'];end=original[wd]['endMinute'];room=original[wd]['location']
   meetings.append({'date':d.isoformat(),'weekday':wd,'startMinute':start,'endMinute':end,'location':room,'normalCatalogLocation':original[wd]['location'],'deliveryMode':'inPerson','sourceWeek':w['WKORD'],'dateProof':'sourcePrintedDate','clockProof':'sourcePrintedMakeupClock' if makeup else 'currentCatalogDisplayedClock','roomProof':'notPrintedForSpecificMakeup' if makeup else 'currentCatalogRoom','sessionKind':'makeup' if makeup else 'class'})
 assert len(meetings)==30 and len(closures)==2
 assert len({m['date'] for m in meetings})==30
 result.append({'courseId':cid,'title':cat[cid]['SBJT_NM'],'nativeClassification':cat[cid]['CPTN_DIV_CD_FNM'],'department':cat[cid]['OPEN_SUST_MJ_CD_NM'],'creditsOriginal':cat[cid]['PNT_TMCNT'],'restrictionOriginal':cat[cid]['TLSN_REST_INFO_CD_NM'],'remarksOriginal':cat[cid]['TLSN_ANNM'],'periodStart':min(m['date'] for m in meetings),'periodEnd':max(m['date'] for m in meetings),'sourceResponseSHA256':j['sourceResponseSHA256'],'meetings':meetings,'closures':closures,'scheduleAllowed':False,'remainingGate':'Specific makeup rooms not directly printed; retain unknown room and request owner decision rather than silently copying catalog room','wholeSchoolCompletionClaim':False})
(R/'cnu-two-dated-chinese-proofs-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('two courses; actual60meetings+4closures; makeuproomgate retained')
