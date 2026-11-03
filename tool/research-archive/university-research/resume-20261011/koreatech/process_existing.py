"""Process only existing exact business-block evidence; do not write product data."""
import copy,datetime as dt,hashlib,json,pathlib
root=pathlib.Path('.');out=root/'work/university-research/resume-20261011/koreatech'
base=root/'assets/timetable/koreatech-unknown-2026-2.json'
grid=root/'work/university-research/catalog-r/koreatech/business-direct-clock-room-followup-v3-20261009/current-business-grid-education.json'
rawpath=root/'work/university-research/catalog-r/koreatech/koreatech-2026-2-public-educational-rows-v1.json'
data=json.loads(base.read_text());prior=copy.deepcopy(data);g=json.loads(grid.read_text());raw=json.loads(rawpath.read_text())['rows'];rby={(r['nativeCourseCode'],r['nativeSection']):r for r in raw};proof=[]
source=g['sources'][0]
for sec,start,end,native in [('02',540,660,'화01A~02B'),('03',660,780,'화03A~04B')]:
 c=next(c for c in data['courses'] if c['courseCode']=='CCT740' and c['section']==sec);before=copy.deepcopy(c);r=rby['CCT740',sec]
 assert c['courseName']=='경영통계및실습' and r['professor']=='성지미' and native in r['rawSchedule']
 assert c['metadata']['originalEducationalFields']==r
 # Printed grid already contains literal 09:00–11:00 / 11:00–13:00 for the exact sections.
 assert '02/성지미' in source['educationalText'] and '03/성지미' in source['educationalText']
 assert c['metadata']['currentBusinessGridProof']['unresolvedNativeSegments']==[native+' 개별 강의실 미게시']
 dates=[];day=dt.date(2026,8,31)
 while day<=dt.date(2026,12,6):
  if day.isoweekday()==2:
   dates.append({'weekday':2,'startMinute':start,'endMinute':end,'classroom':'','date':day.isoformat()})
  day+=dt.timedelta(days=1)
 assert len(dates)==14 and not any(x['date'] in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02']for x in dates)
 c['schedules']=sorted(c['schedules']+dates,key=lambda m:(m['date'],m['startMinute'],m['endMinute'],m['classroom']))
 p=c['metadata']['currentBusinessGridProof'];p['blocks'].insert(0,{'weekday':2,'startMinute':start,'endMinute':end,'classroom':''});p['unresolvedNativeSegments']=[];p['partialRoomScope']=False;p['unassignedRoomsPreserved']=True;p['previousUnresolvedNativeSegments']=before['metadata']['currentBusinessGridProof']['unresolvedNativeSegments'];p['roomAbsenceNotUsedToDiscardPublishedTime']=True
 obsolete=' 일부 요일 강의실 미게시로 확인된 요일만 예약: '+native+' 개별 강의실 미게시.'
 assert obsolete in c['remarks'];c['remarks']=c['remarks'].replace(obsolete,'')+' 화요일도 동일 현재 원문 분반·교수·직접 시각에 대응합니다. 미공개 화요일 강의실은 빈값으로 유지하며 목요일 강의실을 복사하지 않습니다.'
 proof.append({'sourceId':c['sourceId'],'courseCode':'CCT740','section':sec,'originalNativeRow':r,'originalWholeObject':before,'sourceUrl':source['sourceUrl'],'sourceSha256':source['sha256'],'sourcePrintedVersion':source['printedVersion'],'sourceEducationalText':source['educationalText'],'sourceTuesdayWordCoordinates':[w for w in source['educationalWordCoordinates'] if 300<=w['x0']<=440 or w['text'] in ['09:00','~11:00','11:00','~13:00']],'literalWeekday':2,'literalStartMinute':start,'literalEndMinute':end,'classroom':'','newDatedMeetings':dates,'previousRoomOnlyHold':native+' 개별 강의실 미게시','ownDepartmentOnly':True,'schoolWideClockClaim':False,'wholeCurrentChangesConfirmed':False})
changed={p['sourceId']for p in proof};oldby={c['sourceId']:c for c in prior['courses']}
assert len(data['courses'])==791
assert all(c==oldby[c['sourceId']]for c in data['courses']if c['sourceId']not in changed)
for c in data['courses']:
 if c['sourceId']in changed:
  assert c['metadata']['originalEducationalFields']==oldby[c['sourceId']]['metadata']['originalEducationalFields']
  assert all(m in c['schedules']for m in oldby[c['sourceId']]['schedules'])
audit={'researchOnly':True,'completionClaim':False,'wholeSupportClaim':False,'SDKExecutions':0,'productWrites':0,'sourceInputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in [base,grid,rawpath]},'nativeCourses':791,'changedCourses':2,'unchangedWholeObjects':789,'newDatedMeetings':28,'beforeScheduled':sum(bool(c['schedules'])for c in prior['courses']),'candidateScheduled':sum(bool(c['schedules'])for c in data['courses']),'beforeMeetings':sum(len(c['schedules'])for c in prior['courses']),'candidateMeetings':sum(len(c['schedules'])for c in data['courses']),'clockScope':'Exact same current industry-management department, course title/section/professor/weekday blocks. No application to other departments.','newSourceAcquisition':False,'wholeCurrentVerification':False}
for name,obj in [('candidate.json',data),('prior-whole.json',prior),('proof.json',{'audit':audit,'proofs':proof}),('summary.json',audit)]:
 (out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False))
