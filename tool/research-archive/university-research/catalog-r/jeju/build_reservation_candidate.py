"""Immutable research reservations from actual published current UG fields."""
import collections,datetime as dt,json,re
from pathlib import Path
R=Path(__file__).parent
cs=json.loads((R.parent.parent/'catalog-i/jeju-current-whole-educational-review-20261008.json').read_text())['courses']
clock={str(i):((8+i)*60,(8+i)*60+50) for i in range(1,10)}
clock.update({str(i):(1110+(i-10)*50,1155+(i-10)*50) for i in range(10,15)})
clock.update({'1A':(540,615),'2B':(630,705),'4A':(720,795),'5B':(810,885),'7A':(900,975),'8B':(990,1065)})
maprows=json.loads((R/'jeju-current-campus-building-proof-v1.json').read_text())['buildings']
# Only a room number actually listed by the current map plus a matching building
# name (allowing printed 대학/관 abbreviation) proves ARA. Never infer from major.
def campus_of(rooms):
 result=set()
 for room in rooms:
  if room.startswith('사라'):
   result.add('sara');continue
  norm=re.sub(r'대학|\s|관','',room)
  hits=[]
  for b in maprows:
   name=re.sub(r'대학|\s|관','',b['name'])
   if norm.startswith(name) and any(n and re.search(r'(?<![0-9])'+re.escape(n)+r'(?![0-9])',room) for n in b['roomNumbers']):hits.append(b['campus'])
  result.add('ara' if set(hits)=={'ARA'} else 'unknown')
 return next(iter(result)) if len(result)==1 else 'unknown'
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026년 7월 29일 공개 수업시간표의 수강반번호를 보존하며, 공개된 교과목코드는 제한 현황의 동일 수강반·과목명으로 확인한 경우만 표시합니다. 수강반번호를 분반으로 분해하지 않습니다. 7월 이후 폐강·시간 변경은 전체 확인되지 않았습니다. 방식은 미지정으로 사용자가 선택한 방식을 유지합니다. 공식 학기 9월 1일~12월 21일 중 보강 전 12월 7일까지 일반 예약만 만들고 중간시험 10월 20일~26일 및 공휴일을 제외합니다. 12월 8일~14일 보강과 15일~21일 기말시험의 개별 일정은 생성하지 않습니다.'
why=collections.Counter();groups=collections.defaultdict(list)
for r in cs:
 raw=r['rawTimeAndRoom'];reason='';spans=[];rooms=[]
 if r['operatingReview']!='ordinary-clock-current-operation-review':reason=r['operatingReview']
 elif any(s in r['department'] for s in ['의과대학','미래융합']):reason='별도 학사·특수운영 개별 날짜 미확인'
 elif any(s in raw+' '+r['title'] for s in ['플립','Flipped','현장실습','실습기관','봉사','집중']):reason='특수운영 개별 날짜 미확인'
 else:
  # Native room-first format only: [room] dayperiod dayperiod + [room] ...
  parts=list(re.finditer(r'\[([^]]+)\]\s*([^\[\]]+)',raw))
  if not parts or ''.join(m[0] for m in parts).replace(' ','').replace('+','')!=raw.replace(' ','').replace('+',''):reason='원본 강의실·교시 대응 미확인'
  else:
   for part in parts:
    room=part[1];periodtext=part[2].replace(' ','').strip('+');ps=list(re.finditer(r'([월화수목금토일])(\d+[AB]?)',periodtext))
    if not ps or ''.join(p[0] for p in ps)!=periodtext:reason='원본 교시 해석 미확인';break
    for p in ps:
     day='월화수목금토일'.index(p[1])+1;period=p[2]
     if day>5 or period not in clock:reason='공식 주간·야간 시각 범위 밖';break
     start,end=clock[period];spans.append(dict(weekday=day,startMinute=start,endMinute=end,classroom=room));rooms.append(room)
    if reason:break
 campus=campus_of(rooms or re.findall(r'\[([^]]+)\]',raw));meetings=[]
 if not reason:
  d=dt.date(2026,9,1)
  while d<=dt.date(2026,12,7):
   if not(dt.date(2026,10,20)<=d<=dt.date(2026,10,26)) and d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
    meetings += [dict(s,date=d.isoformat()) for s in spans if s['weekday']==d.isoweekday()]
   d+=dt.timedelta(days=1)
 else:why[reason]+=1
 number=re.sub(r'^([0-9]+)\.0$',r'\1',r['enrollmentNumber']);code=r['subjectCode'] or number;dep=r['department'];cl=r['classification'];credit=r['credits']
 groups[campus].append(dict(sourceId=f'jeju/{campus}/2026-2/{number}',campus=campus,academicYear=2026,semester='2',courseCode=code,courseName=r['title'],section='',professor=r['professor'],classification=cl,credits=credit,departments=[dep],departmentCredits={dep:credit},departmentClassifications={dep:cl},sourceSchedule=raw,sourceClassroom=' / '.join(dict.fromkeys(rooms)),scheduleStatus='scheduled' if meetings else 'unrecognized',schedules=meetings,period=dict(startDate='2026-09-01',endDate='2026-12-21'),remarks=notes+(' 캠퍼스 미확인 자료 묶음입니다.' if campus=='unknown' else '')+(' 예약 보류: '+reason if reason else ''),metadata=dict(originalEducationalFields=r,referenceKind='subjectCode' if r['subjectCode'] else 'publishedEnrollmentNumber',publishedEnrollmentNumber=number,canonicalSubjectCode=r['subjectCode'],nativeSection=None,campusScope='Current official building/room matching' if campus=='ara' else 'Explicit 사라 room + official SARA campus' if campus=='sara' else 'Unknown source bucket; no physical campus assertion',deliveryModeStatus='unknown-user-choice',researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,currentActiveStatusVerified=False,heldReason=reason)))
counts={}
for campus,rows in groups.items():
 data=dict(schemaVersion=2,universityId='jeju',campus=campus,campusName={'ara':'아라','sara':'사라','unknown':'캠퍼스 미확인'}[campus],academicYear=2026,semester='2',publishedDate='2026-07-29',sourceUrl='https://jejunu.ac.kr/ara/noticesurvey/outEvent.htm?category=321&act=view&seq=278363',researchOnly=True,completionClaim=False,courses=rows)
 (R/f'jeju-{campus}-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 counts[campus]=dict(rows=len(rows),scheduled=sum(bool(c['schedules']) for c in rows),meetings=sum(len(c['schedules']) for c in rows))
print(json.dumps(dict(counts=counts,held=why),ensure_ascii=False))
