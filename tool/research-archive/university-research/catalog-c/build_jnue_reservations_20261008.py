import json,datetime,re,hashlib
from pathlib import Path
p=Path('work/university-research/catalog-c/jnue-current-20261008')
raw=json.loads((p/'jnue-unknown-2026-2.metadata-only-20261008.json').read_text())
src=json.loads((p/'source-educational-grid.json').read_text())
clock={}
for cell,label in src['sheets'][0]['publishedClockLabels'].items():
 nums=re.findall(r'\d+',label);period=(int(re.findall(r'\d+',cell)[0])-5)//2+1
 if len(nums)==2:clock[period]=[int(n)*60 for n in nums]
# Calendar week excludes unknown actual makeup/exam and event-day operation.
start=datetime.date(2026,9,22);end=datetime.date(2026,12,4)
excluded={'2026-09-24':'추석','2026-09-25':'추석','2026-10-05':'개천절 대체공휴일','2026-10-07':'황학체육대회 운영 불확실일 보류','2026-10-09':'한글날'}
count=0;scheduled=0
for c in raw['courses']:
 c['creditsPublished']=False;c['scheduleStatus']='unrecognized'
 if c['publicEducationCells'][0]['nativeStudyClass']!=c['nativeStudyClass']:raise ValueError('class mismatch')
 if c['departments'][0].startswith('1학년') and all(r['room'] and r['period'] in clock for r in c['publicEducationCells']):
  plans=[]
  day=start
  while day<=end:
   if day.isoformat() not in excluded:
    for r in c['publicEducationCells']:
     if day.isoweekday()==r['weekday']:
      a,b=clock[r['period']]
      plans.append({'date':day.isoformat(),'weekday':day.isoweekday(),'startMinute':a,'endMinute':b,'classroom':r['room'],'sourceCell':r['cell'],'sourceClockCell':'P'+str(5+2*(r['period']-1)),'reservationRangeOnly':True})
   day+=datetime.timedelta(days=1)
  c['schedules']=plans;c['scheduleStatus']='scheduled';c.pop('scheduleHoldReason',None)
  c['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
  c['remarks']='전주교대 2026.9.15. 기준 공식 공개 시간표의 예약 범위입니다. 공개 시간표 칸의 시작·끝(예: 9~10시)을 그대로 사용하며 휴게·실제 강의 종료 시각은 미확인입니다. 50분으로 줄이지 않았습니다. 과목코드·과목 분반·학점·이수구분 미공개(빈 코드·분반; 학점 미확인). 원문 수업반은 별도로 보존하며 과목 분반으로 추정하지 않았습니다. 내부 식별자는 공식 과목번호가 아닌 문서 위치입니다. 캠퍼스명 미공개. 최신 공지 게시일 9/22부터 보강주간 전 12/4까지만 예약합니다. 공휴일과 10/7 체육대회 운영불확실일은 제외했습니다. 12/7~11 보강·12/14~18 시험 실제 계획, 이전 시간표 변경, 폐강 완전성은 미확인입니다.'
  scheduled+=1;count+=len(plans)
raw['sourceReservationRangeOnly']=True
file='jnue-unknown-2026-2.published-partial-20261008.json'
(p/file).write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n')
a={'candidate':{'file':file,'sha256':hashlib.sha256((p/file).read_bytes()).hexdigest()},'metadata':len(raw['courses']),'scheduled':scheduled,'datedPlans':count,'held':len(raw['courses'])-scheduled,'clock':clock,'sourceClockSheet':'1학년','start':str(start),'end':str(end),'excludedDates':excluded,'wholeCompletionClaim':False,'otherGradesClockScopeUnconfirmed':True,'publicClosureSearchCurrentResults':0,'closureAbsenceNotProof':True}
(p/'reservation-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print(a)
