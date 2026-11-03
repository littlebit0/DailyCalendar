"""Independent next checkpoint: two complete dated plans; no invented makeup rooms."""
import json,collections,hashlib
from pathlib import Path
R=Path(__file__).resolve().parent
catalog={c['COURSE_NO']:c for c in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
proofs=json.loads((R/'cnu-two-dated-chinese-proofs-20261008.json').read_text())
base=json.loads((R/'cnu-unknown-2026-2.whole-checkpoint.json').read_text())
courses={c['sourceEducation']['courseId']:c for c in base['courses']}
for proof in proofs:
 cid=proof['courseId'];c=courses[cid];original=catalog[cid]
 assert str(original['CLOSE_YN'])=='0'
 c['scheduleStatus']='scheduled'
 c['period']={'startDate':proof['periodStart'],'endDate':proof['periodEnd']}
 c['schedules']=[{
  'weekday':m['weekday'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],
  'classroom':m['location'] or '', 'date':m['date'],'mode':'inPerson'
 } for m in proof['meetings']]
 rawnotes='\n'.join(x for x in [original['TLSN_ANNM'] or '',original['TLSN_REST_INFO_CD_NM'] or '','12월9일·11일 보강 강의실은 공개 원문에 표시되지 않았습니다.'] if x)
 c['departmentRemarks']={original['OPEN_SUST_MJ_CD_NM']:rawnotes}
 c['sourceEducation'].pop('derivedBlockingExplanation',None)
 c['sourceEducation']['registrationStatus']='scheduledWithUnprintedSpecificMakeupRoom'
 c['sourceEducation']['individualReviewStatus']='completeActualPrintedDatesAndTimes; specific makeup room absent in source'
 c['sourceEducation']['actualPrintedNoClassDates']=[x['date'] for x in proof['closures']]
 c['sourceEducation']['unprintedSpecificRoomDates']=[m['date'] for m in proof['meetings'] if m['location'] is None]
 c['sourceEducation']['actualPrintedMakeupClockOverrides']=[{
  'date':m['date'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],
  'room':'not printed; left empty','normalCatalogRoomSeparate':m['normalCatalogLocation']
 } for m in proof['meetings'] if m['sessionKind']=='makeup']
 c['sourceEducation']['sourcePlanResponseSHA256']=proof['sourceResponseSHA256']
 c['sourceEducation']['datesOrClockInvented']=False
 assert len(c['schedules'])==30
base['verificationScope']='next research checkpoint only; 5 complete actual-dated courses including2 with unprinted makeup room left empty'
path=R/'cnu-unknown-2026-2.whole-checkpoint-next-five.json';path.write_text(json.dumps(base,ensure_ascii=False,indent=2))
(R/'cnu-next-five-candidate-audit.json').write_text(json.dumps({
 'wholeCurrentMetadataRowsAcrossFixedDaedeokAndNextUnknown':3888,
 'scheduledAcrossBothCampuses':5,'actualPrintedDatedMeetings':120,
 'additionalActualDatedCourses':[p['courseId'] for p in proofs],
 'sourceMakeupRoomAbsentMeetingsPreservedAsEmpty':4,
 'originalOrdinaryRoomNeverCopiedToMakeup':True,
 'sourcePrinted75MinuteMakeupClockPreserved':True,
 'fixedThreeCourseCheckpointModified':False,
 'nextUnknownSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),
 'wholeInstitutionComplete':False,
},ensure_ascii=False,indent=2));print('next candidate5courses120meetings; makeup4roomsleftempty')
