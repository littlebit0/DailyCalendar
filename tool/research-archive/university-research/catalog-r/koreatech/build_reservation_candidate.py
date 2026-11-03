"""Scoped current public timetable reservations, no product edits."""
import collections,datetime as dt,json,re
from pathlib import Path
R=Path(__file__).parent
whole=json.loads((R/'koreatech-2026-2-public-educational-rows-v1.json').read_text())
dep=json.loads((R/'koreatech-mecha-2026-2-educational-rows-v1.json').read_text())
groups=collections.defaultdict(list)
for r in dep['rows']:groups[r['nativeCourseCode'],r['nativeSection']].append(r)
closed={(r['nativeCourseCode'],r['nativeSection']) for r in json.loads((R/'koreatech-current-2026-2-changes-education-v1.json').read_text())['rows'] if '폐' in str(r['changeType'])}
def parse(text,bare=False):
 out=[];day=None
 if not isinstance(text,str):return out
 for part in text.replace(' ','').split(','):
  m=re.fullmatch(r'([월화수목금])?(\d+)([AB])?(?:~(\d+)([AB])?)?',part)
  if not m:raise ValueError(text)
  if m[1]:day='월화수목금'.index(m[1])+1
  if day is None:raise ValueError(text)
  a=int(m[2]);b=int(m[4] or m[2]);sa=m[3] or 'A';sb=m[5] or (m[3] if m[3] else 'B')
  lo=(a-1)*2+(sa=='B');hi=(b-1)*2+(sb=='B')
  for x in range(lo,hi+1):
   key=str(x//2+1)+('B' if x%2 else 'A')
   if key not in dep['clock']:raise ValueError(key)
   c=dep['clock'][key];minute=lambda t:int(t[:2])*60+int(t[3:]);out.append((day,minute(c['start']),minute(c['end'])))
 return out
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026-07-28 공개 편람과 2026-07-30 메카트로닉스 시간표의 정확한 과목코드·분반·교시를 대조했습니다. 편람과 아우누리가 다르면 아우누리 값을 따르므로 최신 변경은 별도 확인해야 합니다. 대표 이수구분은 2026학년도 교육과정 기준입니다. 수업 방식 미지정으로 사용자가 선택한 대면·원격·동영상 방식을 유지합니다. 캠퍼스는 개별 강의실의 정확한 매핑이 미확인으로 미지정입니다. 정규 예약은 8월 31일부터 교육심화향상주간 전날 12월 6일까지이며 겨울방학 전날 12월 20일은 산출 경계로 실제 마지막 수업일을 뜻하지 않습니다. 공휴일·개교기념일 및 교육심화·기말시험의 개별 수업을 생성하지 않았습니다.'
courses=[];why=collections.Counter()
for r in whole['rows']:
 key=r['nativeCourseCode'],r['nativeSection'];ds=groups.get(key,[]);reason='';pieces=[]
 if key in closed:reason='공개 변경 목록 폐강·폐설'
 elif not ds:reason='현재 메카트로닉스 개별 강의실·시각 대응 미확인'
 elif len(ds)>1 and key[0]!='MTS100':reason='원본 숫자 분반 중복 및 상충 시간·제목'
 elif any(not x['theoryRoom'] or (x['practicalPeriod'] and not x['practicalRoom']) for x in ds):reason='개별 강의실 미확인'
 elif any('플립러닝' in str(x['remarks']) for x in ds):reason='플립러닝 주차별 실제 운영 미확인'
 elif any(x in str(r['remarks']) for x in ['군이러닝','장기현장','특수','K-MOOC','온라인']) or r['educationMode']:reason='별도 수업 방식·운영 날짜 미확인'
 else:
  try:
   for x in ds:
    for period,room in [(x['theoryPeriod'],x['theoryRoom']),(x['practicalPeriod'],x['practicalRoom'])]:
     if period:pieces += [(*p,str(room)) for p in parse(period,True)]
   if set(p[:3] for p in pieces)!=set(parse(r['rawSchedule'])):reason='현재 편람·학부 교시 불일치'
  except ValueError:reason='공개 교시 문법·시각 미확인'
 meetings=[]
 if not reason:
  # Combine source-contiguous half-hour slots only within same day/room.
  spans=[]
  for day,start,end,room in sorted(set(pieces)):
   if spans and spans[-1]['weekday']==day and spans[-1]['classroom']==room and spans[-1]['endMinute']==start:spans[-1]['endMinute']=end
   else:spans.append(dict(weekday=day,startMinute=start,endMinute=end,classroom=room))
  d=dt.date(2026,8,31)
  while d<=dt.date(2026,12,6):
   if d.isoformat() not in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02']:
    meetings += [dict(s,date=d.isoformat()) for s in spans if s['weekday']==d.isoweekday()]
   d+=dt.timedelta(days=1)
 else:why[reason]+=1
 course=dict(sourceId=f"koreatech/unknown/2026-2/{key[0]}-{key[1]}",campus='unknown',academicYear=2026,semester='2',courseCode=key[0],section=key[1],courseName=r['title'],professor=r['professor'] or '',classification=r['classification'] or '',credits=r['credits'],departments=[r['openingDepartment']],departmentCredits={r['openingDepartment']:r['credits']},departmentClassifications={r['openingDepartment']:r['classification'] or ''},remarks=notes+' 원본 특이사항: '+str(r['remarks'] or '')+' 대상학년·학부: '+str(r['targetGrade'])+'/'+str(r['targetDepartment'])+' 원본 제한: '+json.dumps({k:r[k] for k in ['gradeAndDepartmentRestriction','departmentRestriction','fourthYearQuota','creditsExcluded','cancellationRestricted','educationMode','englishTeaching','combinedClass','combinedGrade']},ensure_ascii=False)+(' 예약 보류: '+reason if reason else ''),sourceSchedule=str(r['rawSchedule']),scheduleStatus='scheduled' if meetings else 'unrecognized',schedules=meetings,period=dict(startDate='2026-08-31',endDate='2026-12-20'),metadata=dict(originalEducationalFields=r,departmentEducationalRows=ds,researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,wholeLatestChangesConfirmed=False,deliveryModeStatus='unknown-user-choice',heldReason=reason,clockScope='Current2026-2mechatronicsdepartmentonly',campusMappingConfirmed=False))
 courses.append(course)
data=dict(schemaVersion=2,universityId='koreatech',campus='unknown',campusName='미지정',academicYear=2026,semester='2',publishedDate='2026-07-28',sourceUrl=whole['sourceUrl'],researchOnly=True,completionClaim=False,courses=courses)
(R/'koreatech-unknown-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(rows=len(courses),scheduled=sum(bool(c['schedules']) for c in courses),appointments=sum(len(c['schedules']) for c in courses),held=why),ensure_ascii=False))
