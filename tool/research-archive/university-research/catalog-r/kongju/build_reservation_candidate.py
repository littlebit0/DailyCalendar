"""Current public contract-undergraduate reservations; research only."""
import datetime as dt
import json
from pathlib import Path
ROOT=Path(__file__).parent
source=json.loads((ROOT/'kongju-contract-2026-2-educational-rows-v1.json').read_text())
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026학년도 2학기 천안공과대학 계약학과 공개 자료의 실제수업시간을 사용합니다. 최신 변경은 통합정보시스템에서 별도 확인해야 합니다. 교수·학점·이수구분 미공개. 수업 방식 미지정으로 사용자가 선택한 대면·원격·동영상 방식을 유지합니다. 정규 예약은 9월 1일부터 보강기간 전날 12월 7일까지이며 공휴일·중간시험·보강·기말시험의 개별 수업을 생성하지 않았습니다. 공식 종강일은 12월 18일입니다.'
courses=[]
for r in source['rows']:
 meetings=[]
 if not r['approvalUnconfirmed']:
  d=dt.date(2026,9,1)
  while d<=dt.date(2026,12,7):
   if d.weekday()==5 and d.isoformat() not in ['2026-09-26','2026-10-03'] and not dt.date(2026,10,20)<=d<=dt.date(2026,10,26):
    minute=lambda s:int(s[:2])*60+int(s[3:])
    meetings.append(dict(date=d.isoformat(),weekday=6,startMinute=minute(r['startTime']),endMinute=minute(r['endTime']),classroom=r['room']))
   d+=dt.timedelta(days=1)
 courses.append(dict(sourceId=f"kongju/cheonan/2026-2/{r['nativeCourseCode']}-{r['nativeSection']}",campus='cheonan',academicYear=2026,semester='2',courseCode=r['nativeCourseCode'],section=r['nativeSection'],courseName=r['title'],professor='',classification='',departments=[r['department']],departmentCredits={},departmentClassifications={},remarks=notes+(' 사업주훈련예정·승인 여부에 따른 변경 가능으로 예약 보류.' if r['approvalUnconfirmed'] else ''),sourceSchedule=r['rawPeriod']+' '+r['startTime']+'~'+r['endTime']+' ['+r['room']+']',scheduleStatus='unrecognized' if r['approvalUnconfirmed'] else 'scheduled',schedules=meetings,period=dict(startDate='2026-09-01',endDate='2026-12-18'),metadata=dict(originalEducationalFields=r,researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,wholeLatestChangesConfirmed=False,deliveryModeStatus='unknown-user-choice',sourceActualTimeOverridesNominalPeriod=True,closureExactNativeOverlap=False)))
data=dict(schemaVersion=2,universityId='kongju',campus='cheonan',campusName='천안',academicYear=2026,semester='2',sourceUrl=source['sourceUrl'],publishedDate='2026-07-21',researchOnly=True,completionClaim=False,courses=courses)
(ROOT/'kongju-cheonan-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(len(courses),sum(bool(c['schedules']) for c in courses),sum(len(c['schedules']) for c in courses))
