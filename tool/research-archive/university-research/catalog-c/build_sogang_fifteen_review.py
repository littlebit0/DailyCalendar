"""Three individually reviewed dated plans; omit conflicting/unknown meetings."""
import datetime
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).parent
base = root/'sogang-unknown-2026-2.twelve-individual-reviewed-next.json'
catalog = json.loads(base.read_text())
proofs = []
configs = [
    ('PHI2006', 'J107', 720, 795, '김준걸', '김준걸',
     {'2026-09-10','2026-09-24','2026-09-30','2026-10-22','2026-12-15','2026-12-17'}, 26),
    ('PHIG085', 'J315', 720, 795, '김준걸', 'Joongol Kim',
     {'2026-10-05','2026-10-26','2026-12-16','2026-12-21'}, 28),
    ('POL2010', 'D601', 540, 615, '이근욱', '이근욱',
     {'2026-09-24','2026-10-20','2026-10-26','2026-12-15','2026-12-21'}, 27),
]
for code, room, start, end, teacher, teacherText, omitted, count in configs:
    source = root/'sogang-current-public-plan-education'/f'{code}-01.json'
    sourceJson = json.loads(source.read_text())
    text, row = sourceJson['educationalText'], sourceJson['currentPublicRow']
    assert row['year']=='2026 학년도' and row['semester']=='2학기' and row['division']=='대학'
    assert row['subjectCode']==code and row['section']=='01' and row['professor']==teacher
    assert row['meetingText'].endswith(f'[{room}]') and teacherText in text
    if code == 'PHI2006':
        assert '화목 12:00–13:15' in text and '9/30 R3' in text
        assert row['exam']=='10.20(화)12:00~13:15[J107]'
        schedule = text.split('10. 수업 일정',1)[1]
        pairs = re.findall(r'(?<!\d)(\d{1,2})/(\d{1,2})(?!\d)',schedule)
        note = '\n현재 공개 분반 계획서의 실제 일반 수업 25회와 현재 공개 10/20 중간시험 1회를 반영했습니다. 계획서에 적힌 9/30은 수요일로 화·목 정규 시각과 맞지 않아 9/29로 임의 보정하지 않고 제외했습니다. 9/10 개강미사·9/24 추석·10/22·12/17 휴강과 실제 시각 미확정인 12/15 기말시험은 생성하지 않습니다. 전자기기 사용·청강 금지 안내를 확인하세요.'
    elif code=='PHIG085':
        assert 'MW 12:00–13:15' in text and row['exam']=='10.21(수)12:00~13:15[J315]'
        schedule = text.split('10. Course Schedule',1)[1]
        pairs = re.findall(r'(?<!\d)(\d{1,2})/(\d{1,2})(?!\d)',schedule)
        note = '\n현재 공개 분반 계획서의 실제 일반 수업 27회와 현재 공개 10/21 중간시험 1회를 반영했습니다. 10/5 공휴일·10/26 중간 자율학습·12/21 기말 자율학습은 휴강이며 12/16 기말시험 실제 시각은 확인 중이므로 일반 강의로 생성하지 않습니다. 전자기기 사용과 청강이 금지되어 있으며 PHI4038 대체·대학원초급과목 안내를 유지합니다.'
    else:
        assert '2026년 2학기' in text and '중간시험 및 기말시험이 없습니다' in text
        schedule = text.split('수업 일정',1)[1]
        pairs = re.findall(r'(?<!\d)(\d{1,2})/(\d{1,2})\s*\([화목월]\)',schedule)
        note = '\n현재 2026년 2학기 개별 계획서에 명시된 강의소개·동문 특강·팀 발표 27회를 반영했습니다. 모든 특강에 전원이 참석해야 하며 최소 두 팀 프로젝트 참여 조건이 있습니다. 9/24 추석과 중간·기말시험 기간은 제외했습니다. 이 강좌는 중간시험·기말시험이 없으므로 현재 목록의 중간시험 예약 10/20도 출석 일정으로 생성하지 않습니다.'
    assert len(pairs)==32,(code,len(pairs))
    meetings=[];printed=[]
    for month,day in pairs:
        date=datetime.date(2026,int(month),int(day));printed.append(date.isoformat())
        if date.isoformat() in omitted:continue
        assert date.isoweekday() in ((1,3) if code=='PHIG085' else (2,4)),(code,date)
        meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),
                         'startMinute':start,'endMinute':end,'classroom':room,'deliveryMode':'inPerson'})
    assert len(meetings)==count and len({m['date'] for m in meetings})==count
    course=next(c for c in catalog['courses'] if c['courseCode']==code and c['section']=='01')
    old=json.loads(json.dumps(course));assert not course['schedules']
    course.update(schedules=meetings,scheduleStatus='scheduled',partialSchedule=True,
                  period={'startDate':meetings[0]['date'],'endDate':meetings[-1]['date']})
    for department in course['departmentRemarks']:course['departmentRemarks'][department]+=note
    assert course['sourceEducationalMetadata']==old['sourceEducationalMetadata']
    proofs.append({'offering':code+'-01','actualMeetings':count,'currentPublicTerm':'2026-2',
                   'planYearExplicitlyPrinted':code=='POL2010',
                   'currentPlanLinkedToExactPublicOffering':True,
                   'sourceCodeTeacherClockMatches':True,'printedDates':printed,
                   'excludedDates':sorted(omitted),'sourceEducationUnchanged':True,
                   'sourceFileSHA256':hashlib.sha256(source.read_bytes()).hexdigest()})
output=root/'sogang-unknown-2026-2.fifteen-individual-reviewed-next.json'
output.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
audit={'whole':1541,'scheduled':15,'datedMeetings':345,'newProofs':proofs,
       'candidateSHA256':hashlib.sha256(output.read_bytes()).hexdigest(),
       'previousTwelveUnchanged':all(a==b for a,b in zip(json.loads(base.read_text())['courses'],catalog['courses']) if a['courseCode'] not in ['PHI2006','PHIG085','POL2010']),
       'productionRegistered':False,'completionClaim':False}
assert audit['previousTwelveUnchanged']
(root/'sogang-fifteen-individual-reviewed-next-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('Research15/345 dated meetings; original metadata retained, no date fixes.')
