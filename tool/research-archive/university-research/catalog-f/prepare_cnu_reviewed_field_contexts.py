"""Reviewed observed field visits/practicum contexts, with missing actual dates explicit."""
import json
from pathlib import Path
R=Path(__file__).resolve().parent;D={}
def put(ids,kind,note):
 for cid in ids.split():D[cid]={'courseId':cid,'kind':kind,'educationNote':note,'scheduleAllowed':False,'sourceContextReviewed':True,'actualFullCourseDatesVerified':False}
put('1101-7019-58','scheduledGroupFieldworkUndated','Week10 group fieldwork/data collection and photo submission. Cannot replace by fixed classroom meeting without actual operation date/time/place.')
put('1107-2015-00','unresolvedFieldOrArchiveAlternative','Week11 is either local heritage field study or online archive study; choice not fixed. No actual trip date/place/time.')
put('1107-3006-00','plannedOnCampusVisitUndated','Week10 campus library rare-books-room visit planned. Actual date/time absent, classroom override unresolved.')
put('1111-1005-00','requiredTripAndExamReplacement','Week7 department trip mandatory; week8 midterm replaced by museum trip and essay. Dates/times not printed, no ordinary exam meeting invented.')
put('1111-2006-00 1111-3017-00 1111-7008-00','plannedHeritageFieldtripUndated','Week5 explicitly heritage fieldtrip. Actual day/time/place not printed.')
put('1111-2020-00 1111-7001-00 1111-7001-01','encouragedIndependentFieldwork','Observed week2 asks students to experience heritage visits voluntarily; not explicit class cancellation or scheduled replacement by itself.')
put('1111-7005-00','recordedTeachingAndIndependentVisitAmbiguity','Attendance rule requires videos watched to end, remote paragraph weekly video with possible in-person switch; header describes museum trips and presentations. Actual current fixed delivery/dates unresolved.')
put('1135-3003-00','vacationPracticumWithoutActualDates','Current plan prescribes4weeks160hours during vacation, separately seminar and supervisor-adjusted visit; actual vacation start/end and scheduled seminar dates not given. Do not project semester classroom clock into workplace hours.')
put('1160-4006-00','currentDeliveryContradictionAndFieldPlacement','Current plan simultaneously states in-person practicum and live-video participation rules. Actual fieldplacement and observation announced later; timetable clock alone cannot decide delivery.')
put('1161-1020-00','plannedConditionalTheatreVisits','Repeated theatre practice in weeks8–10; substitute installation venue if theatre unavailable. Actual venue/date/time not fixed.')
put('1182-2026-00','educationalTopicFalsePositive','Week10 covers purpose/curriculum/safety of industry vocational practice as academic topic, not an actual placement date by itself.')
put('1191-3006-00','independentVisitAssignment','Week8 asks individual case visit and report. Exact submission/visit dates absent; no automatic class cancellation based only on assignment.')
put('1191-4016-00 1191-4016-01 1191-4016-02','plannedSiteVisitsUndated','Week2 site survey/modeling and week5 visit to city regeneration center planned. Actual dates/times/site classroom override not printed.')
put('1196-3033-00 1196-3033-01 1196-3033-02 1196-3033-03 1196-3033-04','oneVisitScheduleToBeCoordinated','Each section has one engineering practice facility tour; week2–4 notes coordinate date, not three repeated tours. Actual datetime missing.')
put('1196-7001-00 1196-7001-01','datedMakeupWithHolidayConflict','Week6 lesson moved to Dec9 due Chuseok, but actual2026 Chuseok is week4. Makeup clock/place not printed; retain inconsistency rather than correcting week/date.')
put('1242-3004-00','conditionalPlannedVisit','Week5 arboretum visit explicitly can change period; actual date/time not fixed.')
put('1242-4001-00','plannedCompanyVisitUndated','Week12 nursery business visit; actual date/time/place not printed.')
put('1243-2005-00','plannedOnCampusObservationUndated','Week12 biological exploration facility observation practice. Actual datetime not printed; no classroom override inferred.')
put('1244-3019-00','plannedIndustrySitesUndated','Week10 wood-industry field visit explicitly planned, exact selected site/date/time missing.')
put('1246-2012-00','educationalReinforcementTopicWithGenericMakeup','Week14 mixes generic makeup and fiber/structure reinforcement topics. Structural reinforcement is not schedule change; actual makeup datetime absent.')
put('1246-3004-00','educationalTopicFalsePositive','Observed week8 is reinforced-earth retaining walls/soil nailing topic, not a makeup class.')
put('1248-3007-00','genericMakeupExamUndated','Week15 makeup/finalexam without actual date/time.')
put('1248-3021-00','threePlannedIndustryVisitsUndated','Week9/11/13 named industry visits and talks, actual dates/times/site travel timing not printed.')
put('1250-1003-00 1251-2003-00 1251-4022-00','plannedFieldVisitsUndated','Specific weekly field visits/contest listed but actual dates/times/venue beyond generic visit labels not printed.')
put('1271-2012-00','holidayMakeupOpenLabUndated','Week5 public holiday/makeup/openlab row; no actual date/time/makeup mechanism.')
put('1271-4018-00','plannedFieldStudyWithConditionalRemotePolicy','Actual fieldstudy planned, remote switch only conditionally notified at least one week prior. Do not assume online course from contingency alone; visit datetime missing.')
put('1282-4013-00','clinicalRotationNoActualDatesOrClocks','Every week describes clinical observation/surgery practice, current catalog displays no time. Rotational actual dates/clock/assignedclinic absent; retain untimed rather than15weekly invented meetings.')
put('1291-2017-00 1291-4033-00','holidayNoClassMakeupUndated','Holiday row explicitly no class, later makeup planned; weeklabel alone does not give actual date/time.')
put('1292-3004-00 1292-4006-00','holidayOnlyWeek','Week4 only holiday, no ordinary subject or timed lesson. Exact percourse makeup unresolved.')
put('1293-3006-00','recordedMakeupUndated','Week5 makeup is online video, actual availability/start/end not printed; no classroom clock reused.')
put('1293-4025-00','holidayAssignmentReplacement','Week4 holiday with personal assignment, not ordinary classroom lesson; actual task deadline absent.')
put('1301-4006-02','fieldPracticeScheduledAfterConsultation','Firstweek requires attendance to decide practical placement schedule; week11/12 actual placement. Public plan contains no finalized practice date/clock.')
put('1720-0001-00','plannedGreenhouseVisitUndated','Week8 advanced greenhouse facility visit planned, actual datetime absent.')
rows=[]
for cid,d in sorted(D.items()):
 p=R/'cnu-current-education'/f'{cid}.json';assert p.exists();j=json.loads(p.read_text());d['sourceResponseSHA256']=j['sourceResponseSHA256'];rows.append(d)
(R/'cnu-reviewed-field-contexts-20261008.json').write_text(json.dumps({'reviews':rows,'count':len(rows),'wholeSemanticReviewComplete':False,'unreviewedContextPendingSeparately':True},ensure_ascii=False,indent=2));print('reviewed field contexts',len(rows))
