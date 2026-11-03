"""Publish only conservative weekly reservation frames within the school's own term.
Raw current native offerings stay complete and immutable; exams are not invented.
"""
from pathlib import Path
from datetime import date,timedelta
import json,hashlib,re,copy,collections
ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent.parent/'catalog-r'/'hanyang'
def save(n,j):
 p=ROOT/n;p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');return hashlib.sha256(p.read_bytes()).hexdigest()
policy=json.loads((ROOT/'hanyang-current-policy-education-receipt-20261008.json').read_text());assert policy['termStartDate']=='2026-09-01' and policy['termEndDate']=='2026-12-21'
HOLIDAYS=set(policy['conservativelyHeldNationalHolidayDates']);results=[]
for campus in ['seoul','erica']:
 original_path=OLD/f'hanyang-{campus}-2026-2.held-v1.json';ds=json.loads(original_path.read_text());stats=collections.Counter()
 assert len(ds['courses'])==({'seoul':2805,'erica':2156}[campus])
 for c in ds['courses']:
  metadata=c['metadata'];native=metadata['originalEducationalRecord'];a=native['officialAliases'][0]
  assert a['suupYear']=='2026' and a['suupTerm']=='20' and a['hakwiGb']=='1'
  assert c['sourceId']==f"hanyang/{campus}/2026-2/{native['classId']}";assert c['courseCode']==a['haksuNo'] and c['section']==a['bunbanNo']
  clock=metadata['verifiedUndatedPublishedClockRoomSlots'];reasons=[g for g in metadata['operatingGaps'] if g not in ['individualExamMakeupAndTeachingDatesUnconfirmed','weekendActualOperatingDatesUnconfirmed']]
  if not clock:reasons.append('exactClockRoomMissing')
  if any(d in ['의학과','의예과'] for d in c['departments']):reasons.append('medicalOwnCourseOperatingPeriodUnconfirmed')
  # Weekends are retained when natively explicit and otherwise regular.
  eligible=not reasons;meetings=[]
  if eligible:
   d=date(2026,9,1)
   while d<=date(2026,12,21):
    if d.isoformat() not in HOLIDAYS:
     for s in clock:
      if d.isoweekday()==s['weekday']:meetings.append({'date':d.isoformat(),**s})
    d+=timedelta(days=1)
  note=('공개 주간 예약 계획, 실제 운영/날짜 미확인. 자체 학부 2026-2 개강9월1일·종강12월21일 범위의 원문 주간 요일·실제시각·실만 예약 틀로 변환했습니다. '
   '개별 출석·중간/기말시험·보강·휴강·운영 전환 날짜는 미확인입니다. 자체 달력에는 시험기간이 없으므로 임의 시험주·종료일을 생성하거나 추정하여 잘라내지 않았습니다. '
   '12월22일은 보강가능일이며 실제 개별 보강일로 생성하지 않았습니다. 현재 공개 계획의 법정공휴일 제외/15주미만 보강 안내를 확인했지만 모든 강좌의 휴일운영이 확정된 것은 아닙니다. '
   '추석9월24~26일·개천절10월3일·대체공휴일10월5일·한글날10월9일은 국가 월력요항 날짜에 따라 보수적으로 예약 보류하며 개별 실제 휴강은 미확인입니다. '
   '실습/집중/혼합/원격 배정·clock-room 불일치·의학과 별도 운영기간이 미확인인 강좌는 날짜를 보류했습니다. 원문 토·일 정규 시각은 그 이유만으로 제외하지 않았습니다. '
   '수업번호/학수번호/분반00과 학과별 이수구분·학점·학생 제한·원문 운영 flag를 모두 보존합니다. 실제 서울/ERICA 기관·강의실 scope를 유지하며 사용자 강의방식3종 선택을 원문 원격·혼합 정보로 덮어쓰지 않습니다. '
   '현재 전체 변경·누적 폐강은 미확인입니다. 현재 공개 전체검색 NetFunnel과 공식 호스트403 경계에서 중단했으며 재조회·로그인·보안 우회하지 않았습니다. ')
  if not eligible:note+=' 이 강좌의 실제 날짜 변환 보류 사유: '+', '.join(dict.fromkeys(reasons))+'. '
  suffix=c['remarks'].split('원문 수업번호:',1)[1];newremarks=note+'원문 수업번호:'+suffix
  previous=c['remarks'];c['departmentRemarks']={dep:newremarks+text[len(previous):] if text.startswith(previous) else text+' / '+note for dep,text in c['departmentRemarks'].items()}
  c['remarks']=newremarks;c['schedules']=meetings;c['scheduleStatus']='scheduled' if eligible else 'unrecognized';c['period']={'startDate':'2026-09-01','endDate':'2026-12-21'} if eligible else None
  metadata['reservationProjection']={'eligible':eligible,'heldReasons':list(dict.fromkeys(reasons)),'kind':'publishedWeeklyReservationPlan','actualAttendanceConfirmed':False,'actualExamDatesConfirmed':False,'actualMakeupDatesConfirmed':False,'rawDeliveryFlagsPreservedWithoutModeOverride':True,'schoolOwnTermEvidence':'hanyang-current-policy-education-receipt-20261008.json'}
  stats['native']+=1;stats['scheduled']+=eligible;stats['datedSlots']+=len(meetings);stats['held']+=not eligible
  stats['scheduledWeekendClasses']+=eligible and any(s['weekday']>5 for s in clock)
  stats.update('held/'+s for s in set(reasons))
 assert len({c['sourceId'] for c in ds['courses']})==len(ds['courses'])
 ds.update({'candidateRevision':'native-regular-reservations-partial-v1','termStartDate':'2026-09-01','termEndDate':'2026-12-21','completionClaim':False,'actualAttendanceConfirmed':False,'currentWholeClosureVerified':False,'predecessorSHA256':hashlib.sha256(original_path.read_bytes()).hexdigest()})
 name=f'hanyang-{campus}-2026-2.native-regular-reservations-partial-v1.json';sha=save(name,ds);results.append({'file':name,'SHA256':sha,'stats':dict(stats)})
save('hanyang-native-regular-reservations-partial-v1-audit.json',{'campuses':results,'nativeTotal':4961,'wholeSchoolCompletionClaim':False,'productionChanged':False,'holidayOmissionIsConservative':True,'individualExamOrMakeupDatesGenerated':False});print(results)
