"""Immutable partial school-published reservation projection; no attendance/current-active claim."""
import copy,hashlib,json,collections
from pathlib import Path
P=Path(__file__).parent
name='kunsan-current-whole-operating-date-checkpoint-next-20261008.json'
a=json.loads((P/name).read_text()); b=copy.deepcopy(a)
assert len(b['courses'])==1718
note='학교가 2026년 7월 23일 공시한 정규 수업 계획입니다. 시간표는 학과 사정에 따라 변경될 수 있어 학교 안내에 따라 통합정보시스템에서 현재 수강반·폐강·분합반·수업시각을 재확인해야 합니다. 9월 4일·9월 9일 폐강 기준일 이후 최종 활성 강좌 전체는 확인되지 않았습니다. 시험·보강·개별 변경 사항은 학교 공지를 확인하세요. 실제 출석이나 개인 수업계획서 전수 확인을 의미하지 않습니다.'
for c in b['courses']:
 c['sourceScheduleStatus']=c['scheduleStatus']
 if c['scheduleStatus']=='untimed':c['scheduleStatus']='unscheduled'
 c['sourceDepartmentRemarks']=copy.deepcopy(c['departmentRemarks']);c['sourceRemarks']=c['remarks']
 c['departmentRemarks']={k:(v+'\n' if v else '')+note for k,v in c['departmentRemarks'].items()}
 c['remarks']=(c['remarks']+'\n' if c['remarks'] else '')+note
 c['sourceEducation']={'projection':'publishedRegularTimetable' if c['schedules'] else 'unresolvedSourcePreserved','actualAttendanceConfirmed':False,'individualPrivatePlanRead':False,'finalActiveScopeVerified':False,'sourceCampusExplicit':None,'datedPlanProof':'kunsan-operating-date-next-audit-20261008.json' if c['schedules'] else None,'clockProof':'current official enrollment clock numeric1–10 actual09:10 start; circled/11+ not inferred','sourcePublicationDate':'2026-07-23','currentPostedByteRecheck':'kunsan-published-plan-package-recheck-next-20261008.json'}
b.update(universityId='kunsan',campus='unknown',campusName='위치 미확인',academicYear=2026,semester='2',publishedDate='2026-07-23',sourceUrl='https://www.kunsan.ac.kr/board/view.kunsan?boardId=BBS_0000009&dataSid=1384672&menuCd=DOM_000000105001002000',researchOnly=True,productionActivationAllowed=False,currentFullOperatingAuditFinished=False,productionProjectionPermitted='validated800PublishedReservationsOnly',finalActiveScopeVerified=False)
f=P/'kunsan-unknown-2026-2.published-regular-800-v3-next-20261008.json';assert not f.exists();f.write_text(json.dumps(b,ensure_ascii=False,indent=2)+'\n')
for x,y in zip(a['courses'],b['courses']):
 assert x['sourceId']==y['sourceId']
 for k in x:
  if k not in ['departmentRemarks','remarks','scheduleStatus']:assert x[k]==y[k]
counts=collections.Counter(c['scheduleStatus'] for c in b['courses']);assert counts=={'scheduled':800,'unrecognized':820,'unscheduled':98}
aud={'candidate':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'source':name,'sourceSHA256':hashlib.sha256((P/name).read_bytes()).hexdigest(),'whole':1718,'publishedReservations':800,'held':820,'explicitUntimed':98,'datedMeetingCount':sum(len(c['schedules']) for c in b['courses']),'nativeEducationUnchanged':True,'sourceIdentityCampusClockRoomCreditsClassificationsSectionsUnchanged':True,'allSourceRemarksPreserved':True,'explicitUntimedNativeStatusPreserved':'sourceScheduleStatus=untimed; model unscheduled, no time invented','finalActiveScopeVerified':False,'individualPrivatePlansWholeRead':False,'completionClaim':False,'productionRegistered':False,'actualDriveNetworkTested':False,'wholeCurrentPublicSource':'kunsan-published-plan-package-recheck-next-20261008.json','schoolCalendarAndHolidayProof':'kunsan-operating-date-next-audit-20261008.json','sourceModeCounts':{'대면':797,'혼합':2,'비대면':1},'limitations':'Current school public package remains served byte-identical; no final-active cancellation list found. No glyph-clock/late-clock/intensive/JST/generic-remote inference. School published reservations only, unknown campus retained. Visible recheck warning persists in class note.'}
aud['datasets']=[]
for campus in ['unknown','saemangeum']:
 d=copy.deepcopy(b);d['campus']=campus;d['campusName']='위치 미확인' if campus=='unknown' else '새만금캠퍼스';d['courses']=[c for c in b['courses'] if c['campus']==campus]
 out=P/f'kunsan-{campus}-2026-2.published-regular-800-v3-dataset-next-20261008.json';assert not out.exists();out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 aud['datasets'].append({'file':out.name,'campus':campus,'courseCount':len(d['courses']),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
assert aud['datedMeetingCount']==18707
out=P/'kunsan-published-regular-800-v3-next-audit-20261008.json';assert not out.exists();out.write_text(json.dumps(aud,ensure_ascii=False,indent=2)+'\n');print(json.dumps(aud,ensure_ascii=False))
