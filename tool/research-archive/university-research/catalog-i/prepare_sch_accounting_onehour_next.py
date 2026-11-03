"""One current titled/time/room-matched one-hour accounting course."""
import hashlib
import json
from datetime import date, timedelta
from pathlib import Path
from prepare_sch_accounting_candidate import HOLIDAYS, EXAM
ROOT = Path(__file__).parent
oldpath = ROOT / 'sch-unknown-2026-2.accounting-twelve-next.json'
oldsha = '7ca163b486d466938ed0d5980d3ccfea7a4c4385981e0c4548b54866fe62cddb'
assert hashlib.sha256(oldpath.read_bytes()).hexdigest() == oldsha
obj = json.loads(oldpath.read_text())
c = next(c for c in obj['courses'] if c['courseCode']=='12797')
assert c['courseName']=='AI비즈니스전략' and c['sourceSchedule']=='화9' and c['sourceClassroom']=='U639'
assert c['credits']==1 and c['sourceEducationalMetadata']['TM_CNT']=='1'
m = []
d = date(2026,8,31)
while d <= date(2026,12,6):
 if d.isoweekday()==2 and d.isoformat() not in HOLIDAYS | EXAM:
  m.append({'weekday':2,'startMinute':1020,'endMinute':1080,'classroom':'U639','date':d.isoformat()})
 d += timedelta(days=1)
c['scheduleStatus']='scheduled';c['schedules']=m
c['sourceClockReviewProfile']='current-onehour-integer9-two-halfhour-reservation'
c['departmentRemarks']['회계학과']='회계학과 현재 전과목 대면 원칙. 현재학기 3학년 공식 시간표 AI비즈니스전략 화9A–9B(17:00–18:00), U639 및 현재 원표 화9/1학점/1시간 일치. 학교 규칙1시간=2개30분교시에 따른 예약60분; 접촉50분을 임의 추정하지 않음. 일반수업 외 시험·보강 시각 미생성; 개별 강의계획 추가 비고 미확인.'
path=ROOT/'sch-unknown-2026-2.accounting-thirteen-next.json';path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
audit={'originalSHA256':oldsha,'candidateSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'wholeMetadata':2598,'scheduled':13,'unscheduled':235,'unrecognized':2350,'datedMeetings':sum(len(c['schedules']) for c in obj['courses']),'addedCourse':'12797','addedMeetings':len(m),'currentClockImage':'sch-accounting-2026-2-grade3.png','sourceLiteral':'화9','sourceReservation':['17:00','18:00'],'schoolRule':'onehour=two30minuteperiods; actual contact shorter not asserted','remainingAccountingPending':['10654','10655'],'pendingReason':'current catalog titles 졸업및취·창업지도 vs image/title 졸업종합지도; no title alias assumption or current individual operating-plan proof','productionRegistered':False,'completionClaim':False}
(ROOT/'sch-accounting-thirteen-next-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit))
