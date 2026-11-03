"""Individual MAT1060 public dated plans; conflicting date never corrected by guess."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
root=Path(__file__).parent
base=root/'sogang-unknown-2026-2.thirty-three-reviewed-next.json'
original=json.loads(base.read_text())
result=json.loads(base.read_text())
proof=[]
for section,start,weekday,examdate in [('01',810,1,'2026-10-26'),('02',930,1,'2026-10-26'),('03',810,3,'2026-10-21')]:
 key='MAT1060-'+section
 p=root/'sogang-current-public-plan-education'/f'{key}.json'
 source=json.loads(p.read_text()); row=source['currentPublicRow']; text=source['educationalText']; compact=re.sub(r'\s+','',text)
 assert row['year']=='2026 학년도' and row['semester']=='2학기'
 assert row['subjectCode']=='MAT1060' and row['section']==section
 assert row['professor']=='김현석' and '김현석' in compact and '2026학년도2학기' in compact and 'MAT1060' in compact
 end=start+100
 clock=f'{start//60:02}:{start%60:02}~{end//60:02}:{end%60:02}'
 assert clock in compact
 assert row['meetingText']==f"{'월' if weekday==1 else '수'} {clock} [RA205]"
 assert '공휴일(대체공휴일)은필요한경우녹화강의로진행' in compact
 assert '미적분학실습I미적분학II(동시수강가능)' in compact
 rawdates=re.findall(r'(\d+)월\s*(\d+)일',text.split('시수',1)[1]);assert len(rawdates)==16
 dates=[dt.date(2026,int(month[-2:]),int(day)) for month,day in rawdates]
 excluded=[];meetings=[]
 finaldate=dt.date(2026,12,21 if weekday==1 else 16)
 for date in dates:
  if date.weekday()+1!=weekday:
   assert section=='03' and date==dt.date(2026,11,28)
   excluded.append(dict(date=date.isoformat(),reason='printedDateDisagreesWithPublicWeekday'));continue
  if date==dt.date(2026,10,5) or date==finaldate:
   excluded.append(dict(date=date.isoformat(),reason='recordedHolidayOrUnknownFinalClock'));continue
  isexam=date.isoformat()==examdate
  meetings.append(dict(date=date.isoformat(),weekday=weekday,startMinute=start,endMinute=start+75 if isexam else end,classroom='RA205'))
 assert len(meetings)==14
 examclock=f'{start//60:02}:{start%60:02}~{(start+75)//60:02}:{(start+75)%60:02}'
 assert examclock in row['exam'] and row['exam'].endswith('[RA205]')
 course=next(c for c in result['courses'] if c['courseCode']=='MAT1060' and c['section']==section)
 assert not course['schedules']
 course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,
  period=dict(startDate=min(m['date'] for m in meetings),endDate=max(m['date'] for m in meetings)),
  scheduleEvidence=dict(basis='currentPublicPlanPrintedWeekDates',ordinaryDateCount=13,publishedExamDateCount=1,actualAttendanceConfirmed=False))
 note='\n현재 공개 분반 계획서의 정규 실습 계획 13회와 공시된 중간시험 1회를 반영했습니다. 정규 100분과 공시 시험 75분을 구분하며, 공휴일의 필요시 녹화 보강과 실제 시각 미확정 기말시험은 고정 출석 일정으로 생성하지 않습니다. 선수학습은 미적분학실습 I·미적분학 II(동시 수강 가능)이며 중간·기말 중 하나라도 미응시하면 F 처리됩니다. 학교 공시 수업 계획이며 실제 변경 공지를 확인하세요.'
 if section=='03':note+=' 공개 계획서의 9회차는 수요일 수업과 맞지 않는 11/28 토요일로 적혀 있어 보류했습니다. 임의로 10/28 등 다른 날짜로 수정하지 않습니다.'
 for dep in course['departmentRemarks']:course['departmentRemarks'][dep]+=note
 proof.append(dict(offering=key,sourceSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),currentCodeTeacherTermClockMatched=True,regular=13,publicExam=1,excluded=excluded,modeUnknownUserChoice=True))
for old,new in zip(original['courses'],result['courses']):
 if old['courseCode']!='MAT1060':assert old==new
out=root/'sogang-unknown-2026-2.thirty-six-reviewed-next.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
assert sum(bool(c['schedules']) for c in result['courses'])==36
assert sum(len(c['schedules']) for c in result['courses'])==825
(root/'sogang-thirty-six-reviewed-next-audit.json').write_text(json.dumps(dict(whole=1541,scheduled=36,datedMeetings=825,prior33Unchanged=True,proofs=proof,candidateSHA256=hashlib.sha256(out.read_bytes()).hexdigest(),productionRegistered=False,completionClaim=False),ensure_ascii=False,indent=2)+'\n')
print('Sogang36/825 candidate; source3 individually reviewed, no invented replacement date')
