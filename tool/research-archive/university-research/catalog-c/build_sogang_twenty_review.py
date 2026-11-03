"""Current pronunciation first section; two conflicting sections stay pending."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
root = Path(__file__).parent
base = root/'sogang-unknown-2026-2.nineteen-reviewed-next.json'
catalog = json.loads(base.read_text())
source = root/'sogang-current-public-plan-education/KLC1017-01.json'
data = json.loads(source.read_text())
text = re.sub(r'\s+', '', data['educationalText'])
row = data['currentPublicRow']
assert 'KLC1017(01분반)' in text and '2026년2학기' in text and '성명:박소영' in text
assert row['subjectCode']=='KLC1017' and row['section']=='01' and row['professor']=='박소영'
assert row['meetingText']=='화,목 16:30~17:45 [J202]' and '화,목16:30~17:45' in text
assert '1.대면강의' in text and '2.국제학생대상(초급)' in text
assert '개강첫날실시,반드시출석하여야함' in text
assert '8주차(10/20,22)' in text and '16주차(12/15,17)' in text
assert '*지필고사없음' in text and '개별발음평가' in text
assert '이번학기공식휴강일및공휴일은9/24(목)총1일임' in text
meetings=[]
date=dt.date(2026,9,1)
while date<=dt.date(2026,12,17):
    if date.weekday() in (1,3) and date!=dt.date(2026,9,24):
        meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':990,'endMinute':1065,'classroom':'J202','deliveryMode':'inPerson'})
    date+=dt.timedelta(days=1)
assert len(meetings)==31
course=next(c for c in catalog['courses'] if c['courseCode']=='KLC1017' and c['section']=='01')
assert not course['schedules']
course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,
    period={'startDate':'2026-09-01','endDate':'2026-12-17'},
    scheduleEvidence={'basis':'currentPublicPlanPrintedWeekDates','dateCount':31,'assessmentDates':['2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'assessmentKind':'individualPronunciationNoWrittenExam','actualAttendanceConfirmed':False})
note='\n국제학생 초급 대상이며 개강 첫날 발음 진단평가에 반드시 출석해야 합니다. 현재 분반의 공개 계획서에 기재된 대면 수업·개별 발음 평가 31회를 반영하고 9/24 추석 휴강은 제외했습니다. 지필고사는 없으며 10/20·22와12/15·17은 발음 평가 수업입니다. 녹음 과제는 출석 수업을 대체하는 동영상 강의가 아닙니다. 학교 공시 수업 계획이며 변경 사항은 학교 공지를 확인하세요.'
for department in course['departmentRemarks']:course['departmentRemarks'][department]+=note
conflicts=[]
for section in ['02','03']:
    d=json.loads((root/f'sogang-current-public-plan-education/KLC1017-{section}.json').read_text())
    assert '수업시간월,수13:30~14:45' in re.sub(r'\s+','',d['educationalText'])
    conflicts.append({'offering':f'KLC1017-{section}','currentPublishedTime':d['currentPublicRow']['meetingText'],'linkedPlanTime':'월,수13:30~14:45','decision':'Hold conflicting current clock versus linked plan; no guessed attendance mapping.'})
output=root/'sogang-unknown-2026-2.twenty-reviewed-next.json'
output.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
old=json.loads(base.read_text())['courses']
assert all(a==b for a,b in zip(old,catalog['courses']) if a['courseCode']!='KLC1017' or a['section']!='01')
assert sum(bool(c['schedules']) for c in catalog['courses'])==20
assert sum(len(c['schedules']) for c in catalog['courses'])==488
(root/'sogang-twenty-reviewed-next-audit.json').write_text(json.dumps({'whole':1541,'scheduled':20,'datedMeetings':488,'previousNineteenUnchanged':True,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidateSHA256':hashlib.sha256(output.read_bytes()).hexdigest(),'currentCoverAndClockVerified':True,'conflictingSectionsHeld':conflicts,'productionRegistered':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print('Research20/488; two explicit source clock conflicts held')
