"""Four independently inspected current linear algebra plans, preserve public exams."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
root=Path(__file__).parent;base=root/'sogang-unknown-2026-2.thirty-six-reviewed-next.json'
original=json.loads(base.read_text());result=json.loads(base.read_text());proof=[]
for section,professor,weekdays,start,room,examdate,examroom in [
 ('01','조장현',{2,4},720,'RA410','2026-10-20','RA410'),
 ('02','최승일',{1,3},630,'RA408','2026-10-26','RA408'),
 ('03','김순영',{2,4},810,'RA310','2026-10-22','R404'),
 ('04','조성희',{3,5},900,'RA310','2026-10-23','RA310')]:
 key='MAT2110-'+section;p=root/'sogang-current-public-plan-education'/f'{key}.json';src=json.loads(p.read_text());row=src['currentPublicRow'];text=src['educationalText'];compact=re.sub(r'\s+','',text)
 assert row['subjectCode']=='MAT2110' and row['section']==section and row['professor']==professor
 assert row['year']=='2026 학년도' and row['semester']=='2학기' and professor in compact and 'MAT2110' in compact and '2026' in compact
 assert '2학기' in compact or '가을학기' in compact or '2026-2' in compact
 assert all(re.search(str(n)+r'주차',compact) for n in range(1,17)) if section!='02' else '16주차' in compact
 end=start+75;clock=f'{start//60:02}:{start%60:02}~{end//60:02}:{end%60:02}'
 assert clock in row['meetingText'] and row['meetingText'].endswith('['+room+']')
 normalized=compact.replace('-', '~').replace('：',':')
 assert clock in normalized or (section=='01' and '12:00~13:15' in normalized)
 assert row['exam'].endswith('['+examroom+']') and clock in row['exam']
 if section=='03':assert '대면으로진행되는' in compact and '9/24:녹화영상으로대체' in compact
 if section=='02':assert '수업진행언어:한국어' in compact and '시험문제:영어로출제됨' in compact and '수강허가서는승인되지' in compact
 if section=='04':assert '개별적인허가를통한수강신청은받지않습니다' in compact and '확인서를제출하지않는학생은수강을허락하지않습니다' in compact
 course=next(c for c in result['courses'] if c['courseCode']=='MAT2110' and c['section']==section);assert not course['schedules']
 meetings=[];d=dt.date(2026,9,2 if section=='02' else 1);last=dt.date(2026,12,14)
 closed={dt.date(2026,9,24),dt.date(2026,9,25),dt.date(2026,10,5),dt.date(2026,10,9)}
 while d<=last:
  if d.isoweekday() in weekdays and d not in closed and not (dt.date(2026,10,20)<=d<=dt.date(2026,10,26)):
   m=dict(date=d.isoformat(),weekday=d.isoweekday(),startMinute=start,endMinute=end,classroom=room)
   if section=='03':m['deliveryMode']='inPerson'
   meetings.append(m)
  d+=dt.timedelta(days=1)
 ex=dt.date.fromisoformat(examdate);m=dict(date=examdate,weekday=ex.isoweekday(),startMinute=start,endMinute=end,classroom=examroom)
 if section=='03':m['deliveryMode']='inPerson'
 meetings.append(m);meetings.sort(key=lambda x:x['date'])
 # Printed 15 ordinary study weeks stop before the final-exam period; final actual clock absent.
 course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,period=dict(startDate=meetings[0]['date'],endDate=meetings[-1]['date']),scheduleEvidence=dict(basis='publishedRegularTimetable',publishedExamDateCount=1,ordinaryDateCount=len(meetings)-1,actualAttendanceConfirmed=False))
 note='\n현재 분반 계획서와 학교 공시 정규 시간표에 따른 수업 계획 및 공시된 중간시험 1회를 반영합니다. 시험기간의 나머지 정규 슬롯과 실제 시각 미확정 기말시험은 생성하지 않습니다. 사이버캠퍼스의 강의노트·과제 공지는 영상강의로 바꾸지 않습니다. 학교 공시 수업 계획이며 변경 공지를 확인하세요.'
 if section=='01':note+=' 선수학습은 미적분학 I·II이며 중간·기말 중 하나라도 미응시하면 F학점이 부여됩니다.'
 elif section=='02':note+=' 미적분학 I 또는 대학수학의 선행 학습이 필요합니다. 한국어 수업·영어 판서 및 영어 시험이며 추가 수강허가서는 승인되지 않습니다.'
 elif section=='03':note+=' 공개 계획서에 따라 대면 강의입니다. 9/24 녹화 대체는 고정 출석 일정으로 생성하지 않으며 중간시험 강의실 R404와 정규 강의실 RA310을 구분합니다. 선수학습은 고교 수학 교과과정입니다.'
 else:note+=' 별도 선수과목은 없으나 자연계 고교 수학 이해가 필요합니다. 개강 첫 시간에 참석하고 수업규정 동의 확인서를 제출해야 하며 개별 수강허가는 받지 않습니다.'
 for dep in course['departmentRemarks']:course['departmentRemarks'][dep]+=note
 proof.append(dict(offering=key,currentPublicHeaderProfessorClockMatched=True,sourceSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),normalCount=len(meetings)-1,exam=dict(date=examdate,room=examroom),sourceMode='inPerson' if section=='03' else 'unknownUserChoice'))
for old,new in zip(original['courses'],result['courses']):
 if old['courseCode']!='MAT2110':assert old==new
out=root/'sogang-unknown-2026-2.forty-reviewed-next.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
assert sum(bool(c['schedules']) for c in result['courses'])==40
count=sum(len(c['schedules']) for c in result['courses'])
(root/'sogang-forty-reviewed-next-audit.json').write_text(json.dumps(dict(whole=1541,scheduled=40,datedMeetings=count,prior36Unchanged=True,proofs=proof,candidateSHA256=hashlib.sha256(out.read_bytes()).hexdigest(),productionRegistered=False,completionClaim=False),ensure_ascii=False,indent=2)+'\n')
print('Sogang40/',count,'candidate')
