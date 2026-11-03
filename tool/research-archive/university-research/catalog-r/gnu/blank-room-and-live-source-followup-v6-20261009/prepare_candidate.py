import collections,copy,datetime as dt,hashlib,json,re
from pathlib import Path
D=Path(__file__).resolve().parent;P=D.parent/'remaining-campus-clock-followup-v5-20261008'
read=lambda p:json.loads(p.read_text())
raw=read(D.parent.parent.parent/'catalogs/gnu-public-course-rows.json')
audit=read(P/'audit.json');held={r['sourceId']:r for r in audit['heldCases']}
clock=audit['clock'];makeup=audit['makeup'];days='월화수목금토일'
pattern=re.compile(r'([월화수목금토일])(\d+(?:,\d+)*)(?:\[([^\]]+)\])?')
new=[];remain=[];oldDates=oldCount=unchanged=0;datasets=[]
for p in sorted(P.glob('gnu-*-2026-2.ordinary-university-guide-v5.json')):
 before=read(p);data=copy.deepcopy(before)
 for prev,c in zip(before['courses'],data['courses']):
  oldCount+=bool(prev['schedules']);oldDates+=len(prev['schedules'])
  if c['schedules']:assert c==prev;unchanged+=1;continue
  r=c['metadata']['originalEducationalFields'];assert r in raw
  decision=None
  if c['sourceId'] not in held:raise AssertionError(c['sourceId'])
  h=held[c['sourceId']];reason=h['reason']
  if reason=='nativeRoomOrSyntaxUnresolved' and '[' not in r['schedule'] and r['method']=='대면수업' and not r['remoteType']:
   decision='nativeRegularClockClassroomUnpublished'
  elif reason=='remoteOrMixedOperation' and r['method']=='비대면수업' and r['remoteType']=='실시간 원격 화상강좌':
   decision='nativeExplicitSynchronousOnline'
  elif c['sourceId']=='gnu/gajwa/2026-2/11006946-001':decision='exactFridayOnlyOtherDayClockHeld'
  matches=list(pattern.finditer(r['schedule']))
  if decision and (not matches or re.sub(r'[,\s]+','',pattern.sub('',r['schedule']))):decision=None
  if decision and (r['closedFirstAnnouncement'] or r['closedSecondAnnouncement'] or c['metadata'].get('currentPublishedNativeIdentityConflict') or '집중' in r['remarks'] or '야간' in r.get('dayNight','')+r['remarks']):decision=None
  blocks=[];omitted=[]
  if decision:
   for m in matches:
    nums=list(map(int,m[2].split(',')));weekday=days.index(m[1])+1
    if len(set(nums))!=len(nums) or nums!=sorted(nums):decision=None;break
    if any(str(n) not in clock for n in nums):
     if decision=='exactFridayOnlyOtherDayClockHeld':omitted.append({'nativeWeekday':weekday,'nativePeriods':nums,'sourceRoom':m[3]or'','reason':'Current institutional clock prints only0–11; no end clock for12; whole Wednesday block withheld.'});continue
     decision=None;break
    for run in nums:
     if blocks and blocks[-1]['weekday']==weekday and run==blocks[-1]['nativePeriods'][-1]+1:
      blocks[-1]['nativePeriods'].append(run);blocks[-1]['endMinute']=clock[str(run)][1]
     else:blocks.append({'weekday':weekday,'nativePeriods':[run],'startMinute':clock[str(run)][0],'endMinute':clock[str(run)][1],'classroom':m[3]or''})
   if not blocks:decision=None
  if not decision:
   remain.append({'sourceId':c['sourceId'],'reason':reason,'originalEducationalFields':r});assert c==prev;unchanged+=1;continue
  meetings=[]
  for block in blocks:
   date=dt.date(2026,9,1)
   while date<=dt.date(2026,12,7):
    if date.isoweekday()==block['weekday'] and date.isoformat()!='2026-10-03':
     actual=makeup.get(date.isoformat(),date.isoformat());ad=dt.date.fromisoformat(actual)
     row={'date':actual,'weekday':ad.isoweekday(),'startMinute':block['startMinute'],'endMinute':block['endMinute'],'classroom':block['classroom']}
     if decision=='nativeExplicitSynchronousOnline':row['deliveryMode']='liveOnline'
     meetings.append(row)
    date+=dt.timedelta(days=1)
  meetings.sort(key=lambda m:(m['date'],m['startMinute'],m['classroom']))
  assert len(meetings)==len({json.dumps(m,sort_keys=True)for m in meetings})
  note='2026-07-24 공개 개설 원문의 요일·교시와 현재2026-2 일반 학부 안내의0–11교시 시각, 자체학기 및 지정보강일에 따른 공개 예약 계획입니다. 실제 출석·최신변경·기말시험 개별 시각은 미확인입니다. 원문 교시 사이 쉬는 시간을 포함한 예약 범위이며 실제 수업량 확정이 아닙니다. 강의실 미게시 행은 빈값 그대로 보존하였으며 장소를 임의 배정하지 않았습니다. 12월15–21일 시험 및10월3일 개별 보강은 생성하지 않습니다.'
  if omitted:note+=' 수요일10–12교시는12교시 끝시각 미게시로 전체 수요일 구간을 보류하고 금요일2–4교시만 제공합니다.'
  if decision=='nativeExplicitSynchronousOnline':note+=' 원문이 실시간 원격 화상강좌로 명시하여 예약의 개별 방식은 실시간 비대면으로 보존합니다. 실제 물리 캠퍼스는 미게시로 unknown을 유지합니다.'
  else:note+=' 원문 대면수업 표시는 교육메타데이터에 보존하며 예약 기본 방식은 사용자가 선택합니다.'
  # Previous research prose is retained in metadata; actual enrollment notes after its first paragraph remain visible.
  source_notes=prev['remarks'].partition('\n')[2]
  c.update(schedules=meetings,scheduleStatus='scheduled',remarks=note+'\n'+source_notes)
  c['metadata'].update(holdReason=None,priorResearchRemarks=prev['remarks'],reservationBasis=decision,clockSecondSemesterApplicabilityConfirmed=True,clockSource='remaining-campus-clock-followup-v5-20261008/current2026-2-university-undergraduate-clock-education.json',classroomPublished=any(b['classroom']for b in blocks),omittedNativeClockScopes=omitted,actualAttendanceConfirmed=False,wholeLatestChangesConfirmed=False)
  new.append({'sourceId':c['sourceId'],'decision':decision,'originalEducationalFields':r,'nativeGeometry':blocks,'omitted':omitted,'meetingCount':len(meetings)})
 out=D/p.name.replace('ordinary-university-guide-v5','blank-room-and-live-v6');out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');datasets.append({'file':out.name,'nativeCount':len(data['courses']),'scheduledCount':sum(bool(c['schedules'])for c in data['courses']),'datedCount':sum(len(c['schedules'])for c in data['courses'])})
assert oldCount==2962 and oldDates==53239 and len(new)==43 and unchanged==4799
report={'researchOnly':True,'completionClaim':False,'actualAttendanceConfirmed':False,'wholeLatestChangesConfirmed':False,'sourceSnapshotDate':'2026-07-24','currentSourceReacquisition':False,'nativeCount':4842,'previousScheduledCount':oldCount,'previousDates':oldDates,'unchangedWholeObjects':unchanged,'newCases':new,'heldCases':remain,'newScheduledCount':len(new),'newDates':sum(c['meetingCount']for c in new),'datasets':datasets,'clock':clock,'makeup':makeup,'semesterBounds':['2026-09-01','2026-12-21'],'regularThrough':'2026-12-07','sourceFiles':{str(p.relative_to(D.parent.parent.parent)):hashlib.sha256(p.read_bytes()).hexdigest()for p in [D.parent.parent.parent/'catalogs/gnu-public-course-rows.json',P/'current2026-2-university-undergraduate-clock-education.json',P/'own-term-makeup-education.json',P/'audit.json']},'verification':{'pythonWholeDeepPreservation':True,'actualThreeModeDrive':False}}
(D/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({k:report[k]for k in ['nativeCount','newScheduledCount','newDates','unchangedWholeObjects']});print(datasets)
