"""Validate actual weekly dates; no arithmetic-derived course end or global fallback."""
import json,re,pathlib,datetime,collections
p=pathlib.Path('work/university-research/catalog-g')
a=json.loads((p/'gachon-current-short-report-week-audit.json').read_text())
known={'AIB02001':'2026-11-14','AIB03001':'2026-09-05','AIB04001':'2026-11-14','AIB05001':'2026-10-10','AIB06001':'2026-10-10'}
reviews={r['courseCode']:r for r in json.loads((p/'gachon-short-report-context-review.json').read_text())['rows']}
rows=[]
for r in a['reports']:
 x=r['sourceRow'];code=x['HAKSU_NO'];duration=int(re.search(r'\((12|4|5)주',x['SUBJECT_NM_KOR'])[1]);w=r.get('weeklyRows',[])
 reasons=[];period=None
 if not all(r['report'].get(k) for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport']):reasons.append('Current course/term/professor identity not all validated')
 if len(w)!=duration:reasons.append('Title duration differs from captured dated weekly row count; includes missing or conflicting plans')
 if not all(v['activityPresent'] for v in w):reasons.append('A dated weekly row has no learning activity; cannot treat blank template as actual teaching')
 if len(r.get('weeklyDateEvidence',[]))>2*len(w) and not reviews.get(code,{}).get('periodDateExpressionsReconciled'):reasons.append('Additional date expressions need contextual reconciliation')
 starts=[];ends=[]
 try:
  for v in w:
   def date(s):
    m,d=map(int,s.split('/'));return datetime.date(2026,m,d)
   start=date(v['startMonthDay']);end=date(v['endMonthDay'])
   if end<start:raise ValueError('Cross-year not validated by this research date reducer')
   starts.append(start);ends.append(end)
  if any(starts[i]<=ends[i-1] for i in range(1,len(w))):reasons.append('Weekly date sequence overlaps or is out of order')
  if len({v['week'] for v in w})!=len(w) or any(w[i]['week']!=w[i-1]['week']+1 for i in range(1,len(w))):reasons.append('Weekly numbering incomplete or repeated')
 except ValueError:reasons.append('Invalid or unvalidated cross-year week date')
 if code in known and starts and not (starts[0] <= datetime.date.fromisoformat(known[code]) <= ends[0]):reasons.append('Explicit AI enrollment actual start lies outside first published week')
 if not reasons and starts:
  period={'start':known.get(code, starts[0].isoformat()),'last':ends[-1].isoformat(),'lastMeans':'Last date of final published teaching week; not a claim of actual final weekday meeting','endExclusive':(ends[-1]+datetime.timedelta(days=1)).isoformat(),'basis':'Actual per-course current PDF dated weekly rows with learning activity; no global period substitution'}
 if code=='60000101' and all(r['report'].get(k) for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport']):
  period={'start':'2026-11-24','last':'2026-12-21','endExclusive':'2026-12-22','basis':'Current official Makers notice121762 and attachment150265; actual course/professor/time matches current catalog; not a global P4 fallback','sourceUrl':'https://www.gachon.ac.kr/bbs/kor/497/121762/artclView.do'}
  reasons=[]
 review=reviews.get(code)
 rows.append({'contextReview':review,'periodBoundValidated':period is not None,'unresolvedOperatingException':review.get('unresolvedMakeupOrDelivery') if review else None,'campus':r['campus'],'category':r['category'],'sourceRow':x,'titleDurationWeeks':duration,'candidatePeriod':period,'weeklyRows':w,'reasons':reasons,'operatingExceptionsNeedReview':any(v['signals'] for v in w)})
b={'researchOnly':True,'completionClaim':False,'actualCurrentShortCount':a.get('shortCurrentCount'),'reportsFetched':len(rows),'full490AuditFinished':a.get('allCurrentShortReportsFetched',False),'candidateCount':sum(x['candidatePeriod'] is not None for x in rows),'rows':rows}
(p/'gachon-short-course-period-candidates.json').write_text(json.dumps(b,ensure_ascii=False,indent=2))
print('fetched',len(rows),'candidates',b['candidateCount'],'unresolved',len(rows)-b['candidateCount'])
