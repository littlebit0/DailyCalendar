from pathlib import Path
import json,copy,re,datetime as dt,hashlib,collections
D=Path(__file__).resolve().parent;B=D.parent/'full-term-ordinary-v3-20261008';R=B.parents[4]
read=lambda p:json.loads(p.read_text())
proof=read(B/'educational-proof.json');clock={int(c['nativePeriod']):(int(c['start'][:2])*60+int(c['start'][3:]),int(c['end'][:2])*60+int(c['end'][3:]))for c in proof['currentClockEvidence']['validatedDayPeriods']}
roomhold='room unavailable or multiple room block correspondence unknown';excluded=set(proof['excludedDates']);changed=[];held=[];oldScheduled=oldDates=untouched=0;outputs=[]
for campus in ['asan','cheonan','unknown']:
 p=B/f'hoseo-{campus}-2026-2.ordinary-planned.json';old=read(p);new=copy.deepcopy(old)
 for c,prev in zip(new['courses'],old['courses']):
  oldScheduled+=bool(prev['schedules']);oldDates+=len(prev['schedules'])
  meta=c['metadata'];native=meta['originalEducationalRecords'];rows=[x['values']for x in native];v=rows[0];holds=meta['reservationHoldReasons']
  if holds!=[roomhold]:untouched+=1;continue
  # Literal single block only; two weekdays/runs remain unallocated.
  m=re.fullmatch(r'([월화수목금])([1-8])(?:~([1-8]))?',str(v[9]or''))
  if not m:held.append({'sourceId':c['sourceId'],'reason':'Multiple native runs/weekday-room correspondence unprinted','originalEducationalRecords':native});untouched+=1;continue
  assert all(r[4]=='대면수업' and r[8]in ['주간','주간(천안)']and tuple(r[9:12])==tuple(v[9:12])for r in rows)
  assert v[10]and v[11] and not re.search('사이버|원격',str(v[10])+str(v[11]))
  assert not meta['campusAllocationRoomConflict'];assert not prev['schedules']
  first,last=int(m[2]),int(m[3]or m[2]);assert first<=last and all(n in clock for n in range(first,last+1));weekday='월화수목금'.index(m[1])+1
  room=f'강의실1: {v[10]} / 강의실2: {v[11]}'
  block={'weekday':weekday,'startMinute':clock[first][0],'endMinute':clock[last][1],'classroom':room};meetings=[]
  date=dt.date(2026,8,31)
  while date<=dt.date(2026,12,18):
   if date.isoweekday()==weekday and str(date)not in excluded:meetings.append({'date':str(date),**block})
   date+=dt.timedelta(days=1)
  c['schedules']=meetings;c['scheduleStatus']='scheduled';meta.update(reservationHoldReasons=[],heldReason='',nativeClockRoomBlocks=[block],sourceRoomAllocationUnknown=True,sourceRoomDisplayMeaning='Native column 강의실1/강의실2 shown literally; neither room selected/assigned; individual room use unknown',previousV3ResearchRemarks=prev['remarks'])
  c['remarks']=prev['remarks'].replace(' 예약보류: '+roomhold,'').replace('9+교시·야간/원격·복수실대응·원문충돌은 보류.', '9+교시·야간/원격·복수시간-실대응·원문충돌은 보류.')+'\n하나의 원문 요일·교시 구간에 공개 강의실1/강의실2를 함께 표시합니다. 각 실 사용·배정 미확인; 어느 한 실로 임의 배정하지 않았습니다. 원문 대면수업/주간 표기는 메타데이터에 보존하며 개별 날짜 실제방식은 미확인으로 사용자 선택을 유지합니다. 캠퍼스 접두어의 공식 정의 미확인으로 캠퍼스는 기존 unknown을 유지합니다.'
  changed.append({'sourceId':c['sourceId'],'originalEducationalRecords':native,'literalClassroom':room,'nativePeriodStart':first,'nativePeriodEnd':last,'weekday':weekday,'meetingCount':len(meetings)})
 new['candidateRevision']='single-run-multiroom-v4';(D/f'hoseo-{campus}-2026-2.single-run-multiroom-v4.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');outputs+=new['courses']
assert oldScheduled==1497 and oldDates==25860 and len(changed)==21 and untouched==2478 and len(held)==94
report={'researchOnly':True,'completionClaim':False,'nativeCount':2499,'sourceEducationalRows':2627,'previousScheduled':1497,'previousDates':25860,'unchangedWholeCourseObjects':2478,'newCases':changed,'remainingRoomPairingAmbiguous94':held,'newScheduled':21,'newDates':sum(c['meetingCount']for c in changed),'scheduledCount':sum(bool(c['schedules'])for c in outputs),'datedCount':sum(len(c['schedules'])for c in outputs),'campusCounts':dict(collections.Counter(c['campus']for c in outputs)),'campusCorrections':0,'periodNineOrAboveInferred':False,'wholeLatestClosureConfirmed':False,'actualAttendanceConfirmed':False,'sourceNativeRoomHeader':['강의실1','강의실2'],'sourceXLS':'work/university-research/catalog-s/hoseo-current-full-courses.xlsx','sourceXLS_SHA256':hashlib.sha256((R/'work/university-research/catalog-s/hoseo-current-full-courses.xlsx').read_bytes()).hexdigest(),'verificationPending':True}
(D/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({k:report[k]for k in ['newScheduled','newDates','scheduledCount','datedCount','campusCounts']})
