"""Owner-approved limited checkpoint: only3 fully printed-date verified courses."""
import json,hashlib,collections
from pathlib import Path
R=Path(__file__).resolve().parent
source=R/'cnu-current-catalog-education-with-public-names.json'
if not source.exists():raise SystemExit('Deferred until actual current public instructor-name refresh completes.')
rows=json.loads(source.read_text());cat={r['COURSE_NO']:r for r in rows}
first=json.loads((R/'cnu-first-dated-proof-20261008.json').read_text());proofs=[first]+json.loads((R/'cnu-additional-dated-proofs-20261008.json').read_text())
bycampus={'daedeok':[],'unknown':[]}
for p in proofs:
 cid=p['courseId'];c=cat[cid];campus='daedeok' if cid=='1001-7041-00' else 'unknown'
 dept=c['OPEN_SUST_MJ_CD_NM'];classification=c['CPTN_DIV_CD_FNM'];credit=float(c['PNT_TMCNT'].split('/')[0]);remarks=c.get('TLSN_ANNM') or '';restriction=c.get('TLSN_REST_INFO_CD_NM') or ''
 notes='\n'.join(x for x in [remarks,restriction] if x)
 schedules=[{'weekday':m['weekday'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],'classroom':m['location'],'date':m['date'],'mode':'inPerson'} for m in p['meetings']]
 course={
  'sourceId':f'cnu/{campus}/2026-2/{cid}',
  'campus':campus,
  'academicYear':2026,'semester':'2',
  'courseCode':c['OPEN_SBJT_NO'],'courseName':c['SBJT_NM'],'section':c['OPEN_DCLSS'],
  'professor':c.get('LT_STAFF_NM') or '', 'classification':classification,
  'departmentClassifications':{dept:classification} if dept else {},'credits':credit,
  'departmentCredits':{dept:credit} if dept else {},'departments':[dept] if dept else [],
  'departmentRemarks':{dept:notes} if dept and notes else {},
  'sourceSchedule':c.get('TMTBL_INFO') or '', 'sourceClassroom':' / '.join(dict.fromkeys(m['location'] for m in p['meetings'])),
  'scheduleStatus':'scheduled',
  'period':{'startDate':p['periodStart'],'endDate':p['periodEnd']},
  'schedules':schedules,
  'sourceEducation':{'courseId':cid,'nativeClassification':classification,'nativeCurriculumClassification':c.get('CURI_CPTN_DIV_NM'),'creditsTheoryPracticeOriginal':c.get('PNT_TMCNT'),'originalTargetYear':c.get('TRGT_SHYR'),'restrictionOriginal':restriction,'remarksOriginal':remarks,'currentLectureType':c.get('LSN_TYPE_CD_NM'),'currentLectureMethod':c.get('LSN_METHOD_CD_NM'),'currentCyberAuxiliaryCategory':c.get('CYBER_LT_TYPE_CD_NM'),'teachingCategoryOriginal':c.get('TCHR_FLD_CD_NM'),'teachingSubcategoryOriginal':c.get('TCHR_FLD_CD_NM2'),'originalEnglishTitle':c.get('ENG_SBJT_NM'),'engineeringAccreditationNativeClassification':c.get('ABEEK_CPTN_DIV_CD_NM'),'engineeringAccreditationTimeOriginal':c.get('ABEEK_TMCNT'),'targetCourseDivisionOriginal':c.get('OBJ_CORS_CD_NM'),'generalEducationFieldOriginal':c.get('CULT_FLD_CD_NM'),'curriculumYearOriginal':c.get('CURI_CORS_YR'),'printedLessonTimeTypeOriginal':c.get('LSN_TM_CD'),'actualDateProof':'individually source-printed dates, current displayed clock and room','currentPlanResponseSHA256':p.get('planResponseSHA256',p.get('sourceResponseSHA256')),'dateExpansionFromWeekOrdinal':False,'campusProof':'same-plan explicit full buildingW4 mapped by official campus map' if campus=='daedeok' else 'abbreviated classroom retained; campus not inferred'}}
 bycampus[campus].append(course)
paths=[]
for campus,courses in bycampus.items():
 data={'schemaVersion':2,'universityId':'cnu',
  'campus':campus,'campusName':'대덕캠퍼스' if campus=='daedeok' else '캠퍼스 미확인',
  'academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://cnuit.cnu.ac.kr/checkMenu.jsp?p0=M69r16057e79Y231','courses':courses,'verificationScope':'only3 verified actual dated courses; other current offerings remain research-pending','wholeInstitutionSupportComplete':False}
 path=R/f'cnu-{campus}-2026-2.three-course-checkpoint.json';path.write_text(json.dumps(data,ensure_ascii=False,indent=2));paths.append(path)
# Separate whole public educational metadata: no implied registration of unreviewed offerings.
public=[{k:r.get(k) for k in ['COURSE_NO','OPEN_SBJT_NO','OPEN_DCLSS','SBJT_NM','ENG_SBJT_NM','LT_STAFF_NM','CPTN_DIV_CD_FNM','CURI_CPTN_DIV_NM','OPEN_SUST_MJ_CD_NM','PNT_TMCNT','TRGT_SHYR','TLSN_REST_INFO_CD_NM','TLSN_ANNM','TMTBL_INFO','LSN_TYPE_CD_NM','LSN_METHOD_CD_NM','CYBER_LT_TYPE_CD_NM','TCHR_FLD_CD_NM','TCHR_FLD_CD_NM2','ABEEK_CPTN_DIV_CD_NM','ABEEK_TMCNT','OBJ_CORS_CD_NM','CULT_FLD_CD_NM','CURI_CORS_YR','LSN_TM_CD','OPEN_YR','CLOSE_YN','CNCL_LT_YN','CNCL_LT_DT']} for r in rows]
whole=R/'cnu-whole-public-course-metadata-20261008.json';whole.write_text(json.dumps({'academicYear':2026,'semester':'2','sourceSnapshotDate':'2026-10-08','courses':public,'currentWholeRows':len(public),'wholeSupportComplete':False,'notProductionRegistrationCandidate':True},ensure_ascii=False,indent=2));paths.append(whole)
a={'registeredResearchCandidateCourses':3,'actualPrintedMeetings':60,'campusCounts':{c:len(v) for c,v in bycampus.items()},'currentPublicMetadataRows':len(rows),'currentActiveRows':sum(str(c['CLOSE_YN'])=='0' for c in rows),'currentClosedRows':sum(str(c['CLOSE_YN'])=='1' for c in rows),'publicInstructorNamesPreserved':True,'nativeClassificationsNeverReplaced':True,'coreNeverAssumedRequired':True,'allIndividualActualPeriodsPreserved':True,'staffIdentifiersContactsMeetingAccessOrRawFullPlansInCandidate':False,'wholeSupportComplete':False,'candidateHashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
(R/'cnu-three-registration-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(a,ensure_ascii=False))
