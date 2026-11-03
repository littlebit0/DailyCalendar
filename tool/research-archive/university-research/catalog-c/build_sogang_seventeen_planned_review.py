"""Published regular plan dates, distinct from per-meeting attendance confirmation."""
import datetime
import hashlib
import json
import re
from pathlib import Path

root=Path(__file__).parent
base=root/'sogang-unknown-2026-2.fifteen-individual-reviewed-next.json'
catalog=json.loads(base.read_text())
proofs=[]
for code,start,end,examDate,examRoom in [
    ('MGT4303',990,1065,'2026-10-26','MA206'),
    ('MGT4306',720,795,'2026-10-21','MA104'),
]:
    source=root/'sogang-current-public-plan-education'/f'{code}-01.json'
    proof=json.loads(source.read_text());text=proof['educationalText'];row=proof['currentPublicRow']
    compact=re.sub(r'\s+','',text)
    assert code in text and '2026-2학기' in compact and '원재환' in compact
    assert '대면강의를원칙으로함' in compact
    assert '비대면강의필요시사전공지함' in compact
    assert '대체시험이나과제등은없음' in compact
    assert row['professor']=='원재환' and row['subjectCode']==code and row['section']=='01'
    assert row['year']=='2026 학년도' and row['semester']=='2학기' and not row['cyber']
    assert row['meetingText']==f"월,수 {start//60:02}:{start%60:02}~{end//60:02}:{end%60:02} [MA206]"
    # Directly reviewed current 2026 bulletin article43 fixes the published
    # regular timetable before term. The actual plan describes14 regular
    # topic weeks and week8/16 exams. The official calendar sets their dates.
    assert '8중간고사' in compact and '16기말고사' in compact
    assert row['exam']==('10.26(월)16:30~17:45[MA206]' if code=='MGT4303' else '10.21(수)12:00~13:15[MA104]')
    meetings=[]
    date=datetime.date(2026,9,1)
    stop=datetime.date(2026,12,14)
    while date<=stop:
        if date.weekday() in (0,2) and date!=datetime.date(2026,10,5) and not (datetime.date(2026,10,20)<=date<=datetime.date(2026,10,26)):
            meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),
                             'startMinute':start,'endMinute':end,'classroom':'MA206','deliveryMode':'inPerson'})
        date+=datetime.timedelta(days=1)
    assert len(meetings)==27
    meetings.append({'date':examDate,'weekday':datetime.date.fromisoformat(examDate).isoweekday(),
                     'startMinute':start,'endMinute':end,'classroom':examRoom,'deliveryMode':'inPerson'})
    meetings.sort(key=lambda x:x['date'])
    course=next(c for c in catalog['courses'] if c['courseCode']==code and c['section']=='01')
    old=json.loads(json.dumps(course));assert not course['schedules']
    course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,
                  period={'startDate':'2026-09-02','endDate':'2026-12-14'},
                  scheduleEvidence={'basis':'publishedRegularTimetable','ordinaryDateCount':27,
                                    'ordinaryAttendanceIndividuallyConfirmed':False,
                                    'publishedExamDateCount':1})
    note='\n학교가 공시한 월·수 정규 시간표와 2026학사일정을 기준으로 일반 수업 계획 27회를 반영했습니다. 10/5 공휴일과 중간시험 기간의 일반 강의는 제외하고, 현재 공개된 필수 중간시험 1회만 지정 시각·강의실로 반영합니다. 기말시험·휴강 보강의 실제 일시는 확인 후 반영해야 하며 비대면 전환은 사전 공지를 확인하세요. 개별 출석일자 확정 기록이 아닌 공시 수업 계획입니다.'
    for department in course['departmentRemarks']:course['departmentRemarks'][department]+=note
    assert course['sourceEducationalMetadata']==old['sourceEducationalMetadata']
    proofs.append({'offering':code+'-01','ordinaryPlannedDates':27,'currentPublishedMidterm':{'date':examDate,'room':examRoom},
                   'sourceFileSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),
                   'currentCodeTeacherTimeAndInPersonConfirmed':True,'sourceEducationUnchanged':True,
                   'ordinaryAttendanceIndividuallyConfirmed':False})
output=root/'sogang-unknown-2026-2.seventeen-individual-and-published-plan-next.json'
output.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
audit={'whole':1541,'scheduled':17,'datedMeetings':401,'individualDatedCourses':15,
       'additionalPublishedRegularPlanCourses':2,'additionalOrdinaryPlannedMeetings':54,
       'additionalCurrentPublishedExams':2,'newProofs':proofs,
       'authority':{'sourceUrl':'https://www.sogang.ac.kr/ko/academic-support/cradle?pkid=19',
                    'currentBulletin2026Article':43,'actualPdfPage':143,
                    'visuallyReviewed':True,'meaning':'The class timetable is fixed before each semester begins.',
                    'termOpening':'2026-09-01','midtermPeriod':['2026-10-20','2026-10-26'],
                    'finalPeriod':['2026-12-15','2026-12-21'],'holidayExcluded':'2026-10-05'},
       'candidateSHA256':hashlib.sha256(output.read_bytes()).hexdigest(),
       'previousFifteenUnchanged':all(a==b for a,b in zip(json.loads(base.read_text())['courses'],catalog['courses']) if a['courseCode'] not in ['MGT4303','MGT4306']),
       'productionRegistered':False,'completionClaim':False}
assert audit['previousFifteenUnchanged']
(root/'sogang-seventeen-individual-and-published-plan-next-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('Research17/401; distinguish54planned+2publishedmidterms, not attendance-confirmed54.')
