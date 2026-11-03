"""Separate research successor; exact native weekly reservations, not attendance proof."""
from pathlib import Path
import json,copy,re,hashlib,collections
from datetime import date,timedelta
P=Path(__file__).parent
OLD=P.parent.parent/'catalog-f'/'hanyang'
policy=json.loads((OLD/'hanyang-current-policy-education-receipt-20261008.json').read_text())
clockPattern=re.compile(r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)')
holidays=set(policy['conservativelyHeldNationalHolidayDates'])
proof=[];campusAudit=[]
for campus in ['seoul','erica']:
 source=OLD/f'hanyang-{campus}-2026-2.native-regular-reservations-partial-v1.json';original=source.read_bytes();(P/f'baseline-{campus}-frozen-v1.json').write_bytes(original)
 ds=json.loads(original);prior=copy.deepcopy(ds);new=[]
 for c in ds['courses']:
  md=c['metadata'];reasons=md['reservationProjection']['heldReasons']
  if c['schedules'] or reasons!=['laboratoryOrPracticumActualOperatingDatesUnconfirmed']:continue
  native=md['originalEducationalRecord'];aliases=native['officialAliases'];a=aliases[0]
  assert native['operatingGaps']==[]
  assert all(row['suupYear']=='2026' and row['suupTerm']=='20' and row['hakwiGb']=='1' and row['suupOprNm']=='일반' and row['suupUnitCnt']==16 for row in aliases)
  fields=['suupTimes','suupRoomNms','campusCd','campusNm','haksuNo','bunbanNo','gyogangsaNms','suupViewtypeNm','teuksuNm','jipjungGanguiYn']
  for field in fields:assert len({str(row.get(field)) for row in aliases})==1
  assert a['campusNm']==('서울' if campus=='seoul' else 'ERICA')
  matches=list(clockPattern.finditer(a['suupTimes']));assert matches and not clockPattern.sub('',a['suupTimes']).replace(',','').strip()
  rooms=[r.strip() for r in a['suupRoomNms'].split(',')];assert len(rooms)==len(matches) and all(r.startswith(a['campusNm']+' ') for r in rooms)
  slots=[dict(weekday='월화수목금토일'.index(m[1])+1,startMinute=int(m[2])*60+int(m[3]),endMinute=int(m[4])*60+int(m[5]),classroom=r) for m,r in zip(matches,rooms)]
  assert slots==md['verifiedUndatedPublishedClockRoomSlots']
  if c['sourceId']=='hanyang/erica/2026-2/24314':
   proof.append(dict(sourceId=c['sourceId'],decision='heldPendingOwnERICALiveSimultaneousScope',nativeViewtype=a['suupViewtypeNm'],reason='Literal on/off simultaneous mode; Seoul general guide gives simultaneous weekly meaning but no individual ERICA operating details refreshed. This is a scope gap, not impossibility.',originalFieldsUnchanged=True));continue
  assert a.get('suupViewtypeNm') in [None,'대면']
  assert not re.search(r'SMART|E-러닝|온라인|원격|HY-LIVE|HY-FLEX|온.?오프|집중',a.get('teuksuNm') or '')
  assert a.get('jipjungGanguiYn') in ['0',None]
  meetings=[];d=date(2026,9,1)
  while d<=date(2026,12,21):
   if d.isoformat() not in holidays:
    meetings.extend(dict(date=d.isoformat(),**s) for s in slots if s['weekday']==d.isoweekday())
   d+=timedelta(days=1)
  assert meetings
  before=copy.deepcopy(c)
  note='공개 정규 주간 예약 계획이며 실제 출석·시험·휴강·보강 날짜 확정이 아닙니다. 실습 시수 값만으로 정규 공개 강의시각 전체를 보류했던 기준을 교정했습니다. 원문 일반운영/16단위, 정확한 요일·HH:mm·해당 캠퍼스 강의실과 자체 2026-2 개강9/1·종강12/21 범위로 예약합니다. 원문 실습/이론 구분, IC-PBL·팀티칭 등 교육 방식과 전체 수강조건을 그대로 보존합니다. 법정공휴일은 보수적 예약 보류이며 실제 개별 휴강은 미확인, 12/22 보강가능일은 개별 보강으로 생성하지 않습니다. 과목별 실제 운영 변경·집중·개인별 배정 증거가 발견되면 별도 검토가 필요하며 최신 전체 폐강/변경 재조회는 완료되지 않았습니다. '
  oldremarks=c['remarks'];suffix=oldremarks.split('원문 수업번호:',1)[1];c['remarks']=note+'원문 수업번호:'+suffix
  c['departmentRemarks']={dep:c['remarks']+text[len(oldremarks):] if text.startswith(oldremarks) else text+' / '+note for dep,text in c['departmentRemarks'].items()}
  c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']=dict(startDate='2026-09-01',endDate='2026-12-21')
  md['reservationProjection'].update(eligible=True,heldReasons=[],resolvedDerivedHoldReasons=['laboratoryOrPracticumActualOperatingDatesUnconfirmed'],sourceSemanticReview='Native exact weekly physical clock/room ordinary16-unit offering; practice-hour pedagogical field is not evidence of irregular allocation',actualAttendanceConfirmed=False)
  assert md['originalEducationalRecord']==before['metadata']['originalEducationalRecord']
  new.append(c['sourceId']);proof.append(dict(sourceId=c['sourceId'],courseCode=c['courseCode'],section=c['section'],campus=campus,teacher=c['professor'],nativeWeeklyClock=a['suupTimes'],nativePhysicalRooms=a['suupRoomNms'],currentNativeHeader=dict(year=a['suupYear'],term=a['suupTerm'],degree=a['hakwiNm']),ordinaryUnitCount=16,delivery=a['suupViewtypeNm'],practiceTeachingType=a['ironSilsNm'],originalOperatingGapEvidence=native['operatingGaps'],derivedPracticeOnlyHoldResolved=True,decision='ordinaryPublishedWeeklyReservation',nativeWeekdayClockRoom=slots,newDatedCount=len(meetings),fullNativeAliasesFingerprint=hashlib.sha256(json.dumps(aliases,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),knownActualDateAllocationContradictionInEducationalFields=False))
 oldMap={c['sourceId']:c for c in prior['courses']};assert all(c==oldMap[c['sourceId']] for c in ds['courses'] if c['sourceId'] not in new)
 ds.update(candidateRevision='ordinary-source-semantic-v2',predecessorSHA256=hashlib.sha256(original).hexdigest(),completionClaim=False,actualAttendanceConfirmed=False)
 name=f'hanyang-{campus}-2026-2.ordinary-source-semantic-candidate-v2.json';(P/name).write_text(json.dumps(ds,ensure_ascii=False,indent=2)+'\n')
 campusAudit.append(dict(campus=campus,metadata=len(ds['courses']),priorScheduled=sum(bool(c['schedules']) for c in prior['courses']),priorMeetings=sum(len(c['schedules']) for c in prior['courses']),newScheduled=len(new),newMeetings=sum(len(c['schedules']) for c in ds['courses'] if c['sourceId'] in new),scheduled=sum(bool(c['schedules']) for c in ds['courses']),meetings=sum(len(c['schedules']) for c in ds['courses']),held=sum(not c['schedules'] for c in ds['courses']),newSourceIds=new,file=name))
(P/'independent-native-course-semantic-review.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
(P/'candidate-audit.json').write_text(json.dumps(dict(campuses=campusAudit,nativeTotal=4961,reviewedPracticeOnly=904,newEligible=903,explicitScopePending=1,allPrior2552DeepUnchanged=True,wholeSourceIdUnionEqual=True,actualAttendanceConfirmed=False,SDKUsed=False,productChanged=False),ensure_ascii=False,indent=2)+'\n')
print([{k:v for k,v in c.items() if k!='newSourceIds'} for c in campusAudit])
