"""Two regular published plans and one individually dated education course."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
root=Path(__file__).parent
base=root/'sogang-unknown-2026-2.twenty-reviewed-next.json'
catalog=json.loads(base.read_text())
proofs=[]
for code,weekday,start,end,room,first,last,examdate,examroom in [
    ('GME4007',1,810,975,'MA402','2026-09-07','2026-12-07','2026-10-26','MA402'),
    ('GME3001',3,810,975,'GA401','2026-09-02','2026-12-02','2026-10-21','K502'),
    ('EDU3033',1,810,920,'J104','2026-09-07','2026-12-07','2026-10-26','J104'),
]:
    source=root/'sogang-current-public-plan-education'/f'{code}-01.json'
    data=json.loads(source.read_text())
    text=re.sub(r'\s+','',data['educationalText']).replace('\x00','')
    row=data['currentPublicRow']
    assert row['subjectCode']==code and row['section']=='01' and code in text
    assert row['professor'] in text and row['year']=='2026 학년도' and row['semester']=='2학기'
    assert '2026' in text and '2학기' in text and '대면' in text
    assert f'{start//60:02}:{start%60:02}' in text and f'{end//60:02}:{end%60:02}' in text
    assert row['meetingText']==f"{'월' if weekday==1 else '수'} {start//60:02}:{start%60:02}~{end//60:02}:{end%60:02} [{room}]"
    assert row['exam']==f"10.{26 if weekday==1 else 21}({'월' if weekday==1 else '수'})13:30~14:45[{examroom}]"
    if code=='EDU3033':
        assert '5주차(10/5)' in text and '보강은녹화동영상강의로대체' in text
        assert '15주차(12/14)' in text and '보강없을시강의없음' in text
        assert '16주차(12/21)' in text and '대면지필평가' in text
        basis='currentPublicPlanPrintedWeekDates'
    else:
        assert '15주차' in text
        basis='publishedRegularTimetable'
    meetings=[]
    date=dt.date.fromisoformat(first)
    while date<=dt.date.fromisoformat(last):
        if date.isoweekday()==weekday and date!=dt.date(2026,10,5) and date.isoformat()!=examdate:
            meetings.append({'date':date.isoformat(),'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room,'deliveryMode':'inPerson'})
        date+=dt.timedelta(days=1)
    expected=13 if code=='GME3001' else 12
    assert len(meetings)==expected
    meetings.append({'date':examdate,'weekday':weekday,'startMinute':810,'endMinute':885,'classroom':examroom,'deliveryMode':'inPerson'})
    meetings.sort(key=lambda m:m['date'])
    course=next(c for c in catalog['courses'] if c['courseCode']==code and c['section']=='01')
    assert not course['schedules']
    course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,
      period={'startDate':first,'endDate':last},scheduleEvidence={'basis':basis,'ordinaryDateCount':expected,'publishedExamDateCount':1,'actualAttendanceConfirmed':False})
    if code=='EDU3033':
        note='\n현재 공개 분반 계획서의 대면 수업 날짜 12회와 공개된 10/26 중간시험 1회를 반영했습니다. 10/5 녹화 보강은 고정 출석 시각으로 만들지 않으며 12/14 조건부 보강·12/21 실제 시각 미확정 기말시험은 제외합니다. 원래 110분 정규 수업과 공개된 75분 중간시험을 구분합니다. 학교 공시 수업 계획이며 변경 사항은 공지를 확인하세요.'
    elif code=='GME4007':
        note='\n학교 공시 정규 시간표와 현재 계획서를 기준으로 일반 수업 계획 12회와 공개된 10/26 중간시험 1회를 반영했습니다. 10/5 휴업과 실제 종료시각 미확정인 12/14 기말시험은 생성하지 않습니다. 정규 165분 수업과 중간시험 75분을 구분합니다. 개별 실제 출석 기록이 아닌 학교 공시 수업 계획이며 변경 사항은 공지를 확인하세요.'
    else:
        note='\n학교 공시 정규 시간표와 현재 계획서를 기준으로 일반 수업 계획 13회와 공개된 10/21 중간시험 1회를 반영했습니다. 정규 강의실 GA401과 시험 강의실 K502, 정규 165분과 시험 75분을 구분합니다. 최종 프로젝트 평가의 실제 일시 미확정 구간은 생성하지 않습니다. 영상 콘텐츠 제작 과제는 출석을 대체하는 VOD 강의가 아닙니다. 학교 공시 수업 계획이며 변경 사항은 공지를 확인하세요.'
    for department in course['departmentRemarks']:course['departmentRemarks'][department]+=note
    proofs.append({'offering':code+'-01','basis':basis,'ordinaryDateCount':expected,'publishedMidterm':{'date':examdate,'room':examroom,'startMinute':810,'endMinute':885},'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'currentCoverProfessorCodeAndClockMatched':True})
output=root/'sogang-unknown-2026-2.twenty-three-reviewed-next.json'
output.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
old=json.loads(base.read_text())['courses'];added={'GME4007','GME3001','EDU3033'}
assert all(a==b for a,b in zip(old,catalog['courses']) if a['courseCode'] not in added)
assert sum(bool(c['schedules']) for c in catalog['courses'])==23
assert sum(len(c['schedules']) for c in catalog['courses'])==528
(root/'sogang-twenty-three-reviewed-next-audit.json').write_text(json.dumps({'whole':1541,'scheduled':23,'datedMeetings':528,'previousTwentyUnchanged':True,'proofs':proofs,'candidateSHA256':hashlib.sha256(output.read_bytes()).hexdigest(),'productionRegistered':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print('Research23/528; preserved prior20 and originalsource, exactexamrooms/durations')
