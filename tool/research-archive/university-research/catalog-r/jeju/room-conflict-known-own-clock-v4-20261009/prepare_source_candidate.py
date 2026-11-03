import copy,datetime as dt,hashlib,json,pathlib,re,shutil,collections
F=pathlib.Path(__file__).parent
BASE=F.parent
clock=json.loads((BASE/'jeju-current-source-proof-v1.json').read_text())
actual=json.loads(pathlib.Path('work/university-research/catalog-i/jeju-current-whole-educational-review-20261008.json').read_text())
assert actual['sourceSnapshotDate']=='2026-07-29' and actual['productionReady'] is False
native={r['enrollmentNumber']:r for r in actual['courses']}
reviews=[];added=[];counts={};priorcount=priordates=0
for campus in ['ara','sara','unknown']:
 p=pathlib.Path(f'assets/timetable/jeju-{campus}-2026-2.json');shutil.copyfile(p,F/f'prior-jeju-{campus}-whole.json');old=json.loads(p.read_text());new=copy.deepcopy(old)
 for r in new['courses']:
  before=next(x for x in old['courses'] if x['sourceId']==r['sourceId'])
  if before['schedules']:priorcount+=1;priordates+=len(before['schedules']);continue
  n=r['metadata']['originalEducationalFields']
  if n['operatingReview']!='ordinary-clock-current-operation-review':continue
  assert n==native[n['enrollmentNumber']]
  reason=r['metadata']['heldReason'];review={'sourceId':r['sourceId'],'originalWholeObject':before,'actualNativeWholeEducationMatched':True,'oldHeldReason':reason,'sourceDecision':'retain individual operating or missing weekday-clock/allocation evidence; title alone not permanent exclusion'}
  reviews.append(review)
  if reason!='같은 요일 시각 중복·복수 강의실 원문 충돌':continue
  raw=n['rawTimeAndRoom'];assert n['rawOperatingMethod']=='' and not any(s in raw for s in ['블렌디드','플립','원격','집중'])
  assert not n['department'].startswith('의과대학 ')
  # Entire original period-first grammar must resolve; no unknown range truncation.
  parts=list(re.finditer(r'([월화수목금])(\d+[AB]?)\[([^\[\]]+)\]',raw));assert ''.join(m[0] for m in parts)==re.sub(r'\s+(?=[월화수목금])','',raw)
  by=collections.defaultdict(list)
  for m in parts:
   assert m[2] in clock['clockMinutes'];by[(m[1],m[2])].append(m[3])
  assert any(len(set(v))>1 for v in by.values())
  spans=[]
  for (day,period),rooms in by.items():
   start,end=clock['clockMinutes'][period];spans.append({'weekday':'월화수목금'.index(day)+1,'startMinute':start,'endMinute':end,'classroom':'','nativeDay':day,'nativePeriod':period,'sourceAllRoomLiterals':rooms})
  assert not any(a!=b and a['weekday']==b['weekday'] and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute']) for a in spans for b in spans)
  dates=[];day=dt.date(2026,9,1)
  while day<=dt.date(2026,12,7):
   if not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and day.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
    dates.extend({k:v for k,v in s.items() if k in ['weekday','startMinute','endMinute','classroom']}|{'date':day.isoformat()} for s in spans if s['weekday']==day.isoweekday())
   day+=dt.timedelta(days=1)
  # Independent weekly anchors instead of candidate date loop.
  independent=set()
  for s in spans:
   date=dt.date(2026,9,1)+dt.timedelta(days=(s['weekday']-2)%7)
   while date<=dt.date(2026,12,7):
    if not dt.date(2026,10,20)<=date<=dt.date(2026,10,26) and date.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:independent.add((date.isoformat(),s['startMinute'],s['endMinute'],''))
    date+=dt.timedelta(days=7)
  assert independent=={(s['date'],s['startMinute'],s['endMinute'],s['classroom']) for s in dates}
  r['schedules']=dates;r['scheduleStatus']='scheduled';assert r['sourceClassroom']==''
  r['metadata'].update(v4PreviousHeldReason=reason,heldReason='',sourceAllNativeRoomPeriodSpans=spans,attendanceClassroomConfirmation='unconfirmed-conflicting-published-rooms',sourceRoomSelected=False,previousV3ResearchRemarks=before['remarks'])
  marker=' 예약 보류: '+reason;assert r['remarks'].count(marker)==1;r['remarks']=r['remarks'].replace(marker,'')+' 같은 원문 요일·교시는 확정돼 공개 예약으로 표시합니다. 강의실은 원문 복수 위치 배정이 미확정이라 빈값을 유지하며 어느 장소도 선택하지 않았습니다. 원문 전체 위치: '+raw+' 실제 강의실·최신 변경·교대 운영은 미확인입니다. 캠퍼스는 기존 원문 증거를 유지하고 추가 추정하지 않습니다.'
  review.update(sourceDecision='same published weekday-period, competing room only; classroom blank/all raw room values retained',ownSpans=spans,reservationCount=len(dates));added.append(review)
 new['researchRevision']='room-conflict-known-own-clock-v4'
 (F/f'jeju-{campus}-2026-2.room-conflict-own-clock-v4.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
 counts[campus]={'native':len(new['courses']),'scheduled':sum(bool(x['schedules']) for x in new['courses']),'reservations':sum(len(x['schedules']) for x in new['courses'])}
assert len(reviews)==127 and len(added)==27 and priorcount==1858 and priordates==67478
proof={'completionClaim':False,'impossibilityClaim':False,'SDKExecutions':0,'networkRequests':0,'wholeCurrentClosureComplete':False,'actualWholeAttendanceVerified':False,'sourceSnapshotDate':actual['sourceSnapshotDate'],'actualCurrentPostedSourceSnapshot':'2026-2 attachment with native undergraduate departments and enrollment numbers; later changes unverified','ordinaryHeldReviewed':127,'oldReasons':dict(collections.Counter(r['oldHeldReason'] for r in reviews)),'allReviewRecords':reviews,'added':added,'addedCount':27,'addedReservations':sum(x['reservationCount'] for x in added),'unchangedWholeObjects':3095-27,'priorScheduledWholeObjects':1858,'priorReservations':67478,'counts':counts,'rawEnrollmentIdentifiersKept':True,'nativeSectionInvented':False,'campusChanges':0,'chosenRooms':0,'unknownClockExtrapolation':0}
(F/'whole127-native-operating-and-room-conflict-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
for name in ['jeju-current-source-proof-v1.json','ordinary-room-program-followup-v2-20261009/current-program-clock-source-receipt.json']:
 p=BASE/name;shutil.copyfile(p,F/p.name)
(F/'source-3095-original-native-education.json').write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n')
print('source-only27/newreservations',proof['addedReservations'],'counts',counts,'unchanged',3095-27)
