"""Immutable native-identity partial public reservation, not current attendance."""
import collections,copy,datetime as dt,hashlib,json,re
from pathlib import Path
P=Path(__file__).parent
source=P/'tuk-research-safe-snapshot-candidates.json';original=json.loads(source.read_text())
proof=json.loads((P/'tuk-current-term-campus-proof-next-20261008.json').read_text());holidays=set(proof['excludedPublicHolidayDates']);courses=[];partial=[]
note='학교가 2026년7월15일 공시한 정규 수업 계획이며9월8일 공개 폐강36개 중 원표에 있었던35개를 제외했습니다. 개강 이후 전체 강좌의 최종 활성·시간·강의실 변경은 미확인입니다. 학교 안내에 따라 통합정보시스템에서 현재 수강반·폐강·분반·장소·시각을 재확인하세요. 수업방식은 사용자가 실제 운영에 맞게 선택해야 하며 실제 출석 확인을 의미하지 않습니다. 반영된 일반 계획은9월1일~12월7일 중 공휴일과 중간고사10월20~26일을 제외한 범위입니다. 학기 종료는12월22일이고 기말고사12월8~21일 및 보강12월15~22일의 개별 일정은 임의 생성하지 않았습니다. 시험·보강·변경은 학교 공지를 확인하세요.'
for old in original['courses']:
 c=copy.deepcopy(old);c['sourceCampusPreparationAlias']=old['campus'];c['sourceScheduleStatus']=old['scheduleStatus'];c['sourceDepartmentRemarks']=copy.deepcopy(old['departmentRemarks']);c['sourceSnapshotSchedules']=copy.deepcopy(old['schedules']);rooms=[x['classroom'] for x in old['snapshotActualSlotCandidates']]
 campus='first' if rooms and all(re.match(r'^(?:[ABCDEGP]동|TIP)',r) or r=='체육관' for r in rooms) else 'unknown';c['campus']=campus
 blocks=[x for x in old['schedules'] if '온라인' not in x['classroom']];held=[x for x in old['schedules'] if '온라인' in x['classroom']]
 meetings=[]
 if old['scheduleStatus']=='scheduled' and blocks:
  day=dt.date(2026,9,1)
  while day<=dt.date(2026,12,7):
   date=day.isoformat()
   if date not in holidays and not '2026-10-20'<=date<='2026-10-26':
    meetings.extend({**b,'date':date} for b in blocks if b['weekday']==day.isoweekday())
   day+=dt.timedelta(days=1)
  assert meetings;c['period']={'startDate':'2026-09-01','endDate':'2026-12-22'}
 c['schedules']=meetings
 if old['scheduleStatus']=='scheduled' and not meetings:c['scheduleStatus']='unrecognized'
 extra=''
 if held:
  extra='\n부분 시간표: 원문 온라인강좌 슬롯은 실시간/동영상 및 출석 시각이 미확인이라 반영하지 않았습니다. '+', '.join(f"{x['weekday']}요일 {x['startMinute']//60:02}:{x['startMinute']%60:02}~{x['endMinute']//60:02}:{x['endMinute']%60:02} {x['classroom']}" for x in held)+'는 휴강 확정이 아니며 실제 운영을 학교에서 확인하세요.'
  partial.append({'sourceId':c['sourceId'],'heldSourceBlocks':held,'physicalSubsetAvailable':bool(meetings)})
 if c['courseName']=='글로벌잉글리시':extra+='\n2026-2 수강안내: 수준별 분반은 구술 테스트 후 최종 확정되므로 본인 분반·강의실·교수명을 확인해야 합니다. 신입생은 일괄신청이며 재수강 등 별도 자격 조건은 학교 수강안내를 확인하세요.'
 c['departmentRemarks']={k:v+'\n'+note+extra for k,v in old['departmentRemarks'].items()};c['remarks']=note+extra
 c['sourceEducation']={'projection':'publishedRegularTimetablePartial' if held and meetings else 'publishedRegularTimetable' if meetings else 'unresolvedSourcePreserved','sourcePublicationDate':'2026-07-15','actualAttendanceConfirmed':False,'finalActiveScopeVerified':False,'sourceDeliveryMode':'unknownUserSelect' if not c.get('deliveryEvidence') else c['deliveryEvidence'],'sourceCampusExplicit':None,'derivedPhysicalCampus':{'campus':campus,'proof':'tuk-current-term-campus-proof-next-20261008.json','exactSourceRooms':rooms},'heldOnlineScope':held,'ordinaryGeneratedScopeEnd':'2026-12-07','termHolidayProof':'tuk-current-term-campus-proof-next-20261008.json','nativeSourceIdRetainedDespitePhysicalCampusProjection':True}
 courses.append(c)
counts=dict(collections.Counter(c['scheduleStatus'] for c in courses));assert counts=={'scheduled':1346,'unrecognized':68,'unscheduled':17};assert len({c['sourceId']for c in courses})==1431
for a,b in zip(original['courses'],courses):
 for key in a:
  if key not in ['campus','scheduleStatus','schedules','departmentRemarks']:assert a[key]==b[key]
audit={'researchOnly':True,'completionClaim':False,'productionRegistered':False,'currentFullOperatingAuditFinished':False,'finalActiveScopeVerified':False,'source':source.name,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'whole':1431,'sourceRows':2242,'counts':counts,'partialOnlineScope':partial,'datedMeetingCount':sum(len(c['schedules'])for c in courses),'datasets':[],'limits':['Separate company/industry identity still unavailable','July snapshot with observed36 closures; no final whole current additions/time changes claimed','Unknown source mode requires user choice','Native main scope alias remains in sourceId; real physical campus is separately proven or unknown','No individual private plan or actual network Drive verification']}
for campus in ['first','unknown']:
 cc=[c for c in courses if c['campus']==campus];d={'schemaVersion':2,'universityId':'tuk','campus':campus,'campusName':'제1캠퍼스' if campus=='first' else '위치 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-07-15','sourceUrl':'https://www.tukorea.ac.kr/bbs/ce/201/49833/download.do','courses':cc,'counts':dict(collections.Counter(c['scheduleStatus']for c in cc)),'researchOnly':True,'productionRegistered':False,'completionClaim':False,'currentFullOperatingAuditFinished':False,'finalActiveScopeVerified':False,'productionProjectionPermitted':'validated1346JulyPublishedPlansOnly'}
 f=P/f'tuk-{campus}-2026-2.published-regular-1346-next-20261008.json';assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');audit['datasets'].append({'file':f.name,'campus':campus,'courseCount':len(cc),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
f=P/'tuk-published-regular-1346-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in audit.items()if k not in ['partialOnlineScope']})
