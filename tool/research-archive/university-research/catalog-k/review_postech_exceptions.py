"""Manual source decisions for all 35 actually observed public-plan candidates."""
import json
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parent
candidates=json.loads((ROOT/'postech-operating-exception-candidates.json').read_text())['reports']
plans={(r['code'],r['section']):r for r in json.loads((ROOT/'postech-2026-2-public-plan-audit.json').read_text())['reports']}
rows=json.loads((ROOT/'postech-2026-2-normalized-research.json').read_text())['courses']
normal=['IMEN303-01','IMEN411-01','IMEN110-01','IMEN110-02','IMEN110-03','ENTP201-01','EECE492-01','CMST409-01','SOSC436-01']
weeks={'IMEN200-01':[8,16],'EECE276-01':[8,16],'MATH102-06':[6],'SEMI211-01':[8,16],'SOSC449B-01':[8,16],'MECH280-01':[16],'MECH199-01':[8],'AIGS102-01':[2,6],'GEDU186-01':[3,13]}
exact={'CHEM211-01':['2026-10-05'],'SOSC451-01':['2026-10-05','2026-10-26','2026-10-28','2026-12-21','2026-12-23'],'CMST410-01':['2026-10-05','2026-10-28','2026-12-23'],'CMST499B-01':['2026-09-18','2026-09-25','2026-10-09','2026-12-25'],'GEDU136-01':['2026-10-26','2026-12-21'],'GEDU171-01':['2026-09-24'],'GEDU171-02':['2026-10-05'],'LIFE216-01':['2026-09-24','2026-10-27','2026-10-29']}
notes={
'IMEN371-01':('regularWithUndatedMakeup','Regular Friday classes posted; definite online/lunch makeups announced without dates or clocks. Preserve ordinary slots, no added makeup occurrence.'),
'CHEB207-01':('conditionalListedMeeting','Tue17:00-18:15 is exercise/makeup only if announced beforehand. Other published meetings remain regular; do not repeat this Tuesday slot.'),
'CHEB199-01':('individualAgreement','No fixed research timetable; Thu18:00-18:50 merely provisional. Separate orientation announced later.'),
'CITE201-01':('datedPlanConflict','Header current2026-2 but first9/4 before official9/7 start and subsequent intervals mismatch. No conversion of stale dated body.'),
'MATH230-01':('regularWithHolidayAndTentativeExams','Chuseok D-1 may mean9/23 although posted meetings do not necessarily match; no inferred date. Foundation Day holiday is12/3 official. Oct27/Dec22 12:30-15:30 exams explicitly Tentative, do not create confirmed dated events.'),
'MATH230-02':('regularWithHolidayAndTentativeExams','Chuseok and Foundation Day cancellations explicitly noted; preserve dates from official holidays independently, not by guessing lecture-week dates. Oct27/Dec22 exams tentative.'),
'CMEF304-01':('normalConditionalPolicy','Ordinary first orientation; makeup only in event of future cancellation, no current cancellation asserted.'),
'MATH199-01':('datedAndIndividualAgreement','Sep10 introduction in104 plus Dec17 planned presentation; weeks2-14 independent work. No weekly recurrence. General course clock not explicitly a separate presentation duration.'),
'AMSE199-01':('individualAgreementPartialClock','Second-weekTuesday08:00 first introduction,6weekly introductions then individual labs. End clock and explicit calendar dates absent. No invented dated occurrence.'),
}
review=[]
for c in candidates:
 key=c['code']+'-'+c['section'];decision,note=notes.get(key,('regularWithPublishedExceptions','Published no-class weeks/dates retained separately; no assumed calendar conversion for plain week labels.'))
 if key in normal:
  decision='ordinaryPostedSchedule';note='Orientation or attendance policy is not an extra date/closure. Hybrid lectures explicitly retain scheduled offline attendance/team work. No withdrawal of regular slots from this text.'
 if key=='SOSC451-01':note+=' Plan12/8(W) is actually Tuesday2026: preserve disagreement, do not generate extraTuesday nor silently fix date.'
 if key=='LIFE216-01':note+=' Exam12/12 contradicts same-line12/21-24; keep exam unresolved.'
 if key=='GEDU136-01':note+=' Week8Wed10/28 blank topic is not explicit cancellation. Oct5 movie-topic contradicts official holiday; keep body/holiday conflict. Cross-cultural partner meetings negotiated individually, not extra fixed clock.'
 if key=='MECH280-01':note+=' Later lab sessions are GroupA/B with Break sessions; rawweeklyclock does not authorize each student to attend both groups. Group identity/actual dates absent.'
 if key=='MECH199-01':note+=' OfficehourWed20:30-21:30 is not class, objectives refer to2026-1 despite current header.'
 if key=='CMST499B-01':note+=' Dec25 is Christmas2026; plan labels it finals but official finalperiod endsDec24. Exclusiondate is explicit, examlabel is inconsistent.'
 review.append({'code':c['code'],'section':c['section'],'sourceUrl':c['sourceUrl'],'manualSourceReviewed':True,'decision':decision,'reason':note,'sourceLines':c['lines'],'explicitNoClassDates':exact.get(key,[]),'publishedNoClassWeeksWithoutGeneratedDates':weeks.get(key,[]),'confirmedAdditionalDatedMeetings':[]})
assert len(review)==35 and len({r['code']+'-'+r['section'] for r in review})==35
(ROOT/'postech-operating-exceptions-manual-review.json').write_text(json.dumps({'researchOnly':True,'all35SourceCandidatesManuallyReviewed':True,'completionClaim':False,'decisionCounts':dict(Counter(x['decision'] for x in review)),'reviews':review},ensure_ascii=False,indent=2))
# A metadata-only offering is safe to preserve, but is not proof that all actual class times have been provided.
untimed=[]
for r in rows:
 if r['scheduleStatus']!='unscheduled':continue
 code=r['courseCode'];plan=plans[(code,r['section'])];kind='timeUnpublished'
 if code.startswith('WI'):kind='zeroCreditWritingRequirement'
 elif code.startswith('YSOC'):kind='approvedExternalOnlineOffering'
 elif '연구' in r['courseName'] or '논문' in r['courseName']:kind='individualResearchScheduleUnpublished'
 untimed.append({'course':r,'sourcePlanUrl':plan['sourcePlanUrl'],'metadataOnlyPreservationSafe':True,'actualTimeCoverageComplete':False,'kind':kind,'generatedRecurringMeetings':[],'sourceOperatingSections':plan['publicOperatingSections']})
assert len(untimed)==70
(ROOT/'postech-safe-metadata-only-offerings.json').write_text(json.dumps({'researchOnly':True,'metadataOnlyOfferingCount':70,'doesNotMeanPublishedUntimedCourseCanNeverMeet':True,'courses':untimed},ensure_ascii=False,indent=2))
print('Reviewed35; metadata-only70; no guessed times/dates generated')
