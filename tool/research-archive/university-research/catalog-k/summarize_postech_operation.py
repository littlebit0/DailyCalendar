"""Preserve actual current plan evidence separately from weekly recurrence eligibility."""
import json
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent
plans=json.loads((ROOT/'postech-2026-2-public-plan-audit.json').read_text())['reports']
rows=json.loads((ROOT/'postech-2026-2-normalized-research.json').read_text())['courses']
by={(r['code'],r['section']):r for r in plans}
notes={
'CSED199':'Only first introductory session; subsequent individual laboratory agreement. First time may differ from listed clock. Do not create semester weekly recurrence.',
'MATH199':'Current plan explicitly introduces Sep10 and final presentation Dec17; weeks2-14 autonomous student/adviser agreement. General freshman page dates Sep4/Dec11 are stale and not applied.',
'CHEB199':'Two research laboratories five weeks each; individual agreement. Thursday18:00-18:50 is a provisional default, not confirmed individual timetable. Orientation separately announced.',
'PHYS199':'Lab-tour and individually mentored research tracks can change; raw lecture clock does not prove all individual research meetings.',
'AMSE199':'First week no class; second-week Tuesday08:00 Engineering1Room118, six-week departmental introductions, then individual labs. End clock and complete dates unpublished; no generated date/end.',
'MECH199':'Week8 no class. Current header but objective body says2026-1; Wednesday20:30 office hour is not class.',
'IMEN199':'Individual faculty/research matching; current plan contains no weekly operating detail.',
'CHEM199':'Mentor choice, safety preparation and lab research week4-16; raw schedule absent, no invented time.',
'LIFE199':'Lab assignment and mentored research; schedule absent.',
'EECE199':'Introduction time/room announced later; individual project/mentor participation; no invented time.',
'CITE199':'No published clock or operating sections.',
'AIGS102':'Physical lecture venue posted but clock absent. W2/W6 no class; no invented clock.',
'IMEN371':'Online or lunch makeups announced as required because Friday holidays; exact makeup dates/time absent.',
'CHEB207':'Tuesday17:00-18:15 slot is conditional exercise/makeup announced before use; do not repeat unconditionally.',
'CITE201':'Current header but body first session9/4 precedes current Sep7 start; dated plan needs freshness correction. Do not apply all dated intervals as2026.',
'LIFE216':'Final exam line says12/12 and also12/21-12/24 in same line. Preserve conflict; do not choose either as exact exam date.',
}
review=[]
for row in rows:
 key=(row['courseCode'],row['section']);plan=by[key]
 if row['scheduleStatus']!='scheduled' or row['courseCode'] in notes:
  code=row['courseCode'];reason=notes.get(code)
  if code.startswith('WI'):
   reason='Published zero-credit writing-intensive requirement; individual writing interviews/linked HASS assessment. No separate weekly clock posted; do not copy HASS meetings.'
  elif code.startswith('YSOC'):
   reason='Prior-approved Yonsei online-course applicants only; current POSTECH public schedule blank. No invented external clock.'
  review.append({'code':code,'section':row['section'],'scheduleStatus':row['scheduleStatus'],'sourceUrl':plan['sourcePlanUrl'],'review':reason or ('Public clock is absent; no synthetic schedule permitted.' if row['scheduleStatus']=='unscheduled' else 'Multiple time lines and partial room lines cannot be paired from list alone; see explicit plan time-room evidence.'),'publishedOperatingSections':plan['publicOperatingSections'],'automaticWeeklyRecurrenceApproved':False})
summary={'researchOnly':True,'productionActivationComplete':False,'currentScope':418,'currentPlansChecked':418,'allCodeSectionTermIdentityMatches':all(r['identityMatches'] for r in plans),'classificationCounts':dict(Counter(r['departmentClassifications'][r['departments'][0]] for r in rows)),'scheduleStatusCounts':dict(Counter(r['scheduleStatus'] for r in rows)),'listedProfessorLiteralMismatch':[{'code':r['code'],'section':r['section']} for r in plans if r['listedProfessorPresent'] is False],'verifiedProfessorAlias':{'CSED490M-01':'Lee Namhoon / 이남훈, official faculty page evidence stored separately'},'latestPublicScopeRecheck':'418 current; no added, removed or changed fields on capture2026-10-07','cancellationCoverage':'Public list/detail exposes no cancelled-status field. Current public list unchanged; internal bulletin cancellation announcements not accessed. Not a claim that all cancellations are verified.','semesterBoundary':'Official start2026-09-07; finals2026-12-21..24; winter vacation2026-12-28. Separate last instructional date not explicitly published.','operatingReviewCount':len(review),'remaining':'35 keyword candidates need complete manual exception/date audit; ordinary recurring eligibility not yet established for entire scheduled subset.'}
(ROOT/'postech-public-plan-completeness-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
(ROOT/'postech-required-operating-evidence.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'reviews':review},ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False))
