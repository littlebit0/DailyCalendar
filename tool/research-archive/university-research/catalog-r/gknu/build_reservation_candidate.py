"""Frozen educational reservation candidate; no product files or actualattendance."""
import datetime as dt
import json
from pathlib import Path
ROOT=Path(__file__).parent
rows=json.loads((ROOT/'gknu-glocal-2026-2-native-education-rows-v1.json').read_text())['rows']
weekdays={'월':1,'화':2,'수':3,'목':4,'금':5}
closed={'2026-09-24','2026-09-25','2026-10-05','2026-10-09'}
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026-07-13 공개 학부 전공 시간표이며 최신 변경은 별도 확인이 필요합니다. 수업 방식은 미지정이며 사용자가 선택한 대면·원격·동영상 방식을 유지합니다. 공휴일, 중간시험, 기말시험, 보강 지정기간의 개별 수업 시각은 생성하지 않았습니다. 학기 종료 경계 12월 20일은 공식 겨울방학 12월 21일의 전날로 산출한 경계이며 마지막 수업일을 뜻하지 않습니다. 정규 예약은 보강 전날인 12월 7일까지 생성했습니다.'
counts={}
for campus in ['unknown','yecheon']:
 courses=[]
 for row in rows:
  actualcampus='yecheon' if row['rawRoom'].startswith('KD') else 'unknown'
  if actualcampus!=campus:continue
  periods=[int(n) for n in row['rawMeeting'][1:].split(',')]
  known=all(0<=n<=9 for n in periods)
  meetings=[]
  if known:
   date=dt.date(2026,9,1)
   while date<=dt.date(2026,12,7):
    if date.isoweekday()==weekdays[row['rawMeeting'][0]] and date.isoformat() not in closed and not dt.date(2026,10,20)<=date<=dt.date(2026,10,26):
     meetings.append({'date':date.isoformat(),'weekday':date.isoweekday(),'startMinute':(8+min(periods))*60,'endMinute':(8+max(periods))*60+50,'classroom':row['rawRoom']})
    date+=dt.timedelta(days=1)
  major=row['sourceHeading'].removeprefix('단과대구분없음 ')
  courses.append({'sourceId':f"gknu/{campus}/2026-2/{row['nativeCourseCode']}-{row['nativeSection']}",'campus':campus,'academicYear':2026,'semester':'2','courseCode':row['nativeCourseCode'],'courseName':row['title'],'section':row['nativeSection'],'professor':row['professors'],'classification':row['classification'],'credits':float(row['creditHours'].split('-')[0]),'departments':[major],'departmentCredits':{major:float(row['creditHours'].split('-')[0])},'departmentClassifications':{major:row['classification']},'remarks':notes+(' 야간 교시의 실제 종료 시각 미확인으로 예약 보류.' if not known else ''),'sourceSchedule':row['rawMeeting']+'['+row['rawRoom']+']','scheduleStatus':'scheduled' if known else 'unrecognized','schedules':meetings,'period':{'startDate':'2026-09-01','endDate':'2026-12-20'},'metadata':{'originalEducationalFields':row,'researchOnly':True,'actualAttendanceConfirmed':False,'actualPhysicalDatesConfirmed':False,'wholeLatestChangesConfirmed':False,'deliveryModeStatus':'unknown-user-choice','fourYearScopeSource':'https://adl.gknu.ac.kr/intro/greeting','nativeBarePeriodSource':'current2026-2registrationguide-PC-image14','dayExactClockSource':'https://www.gknu.ac.kr/main/html.do?menu_idx=134','clockSupported':known}})
 data={'schemaVersion':2,'universityId':'gknu','campus':campus,'campusName':'미지정' if campus=='unknown' else '예천','academicYear':2026,'semester':'2','publishedDate':'2026-07-13','sourceUrl':'https://gle.gknu.ac.kr/module/bbs/view.php?mid=/community/notice&bdno=1695&rdno=167917','researchOnly':True,'completionClaim':False,'courses':courses}
 (ROOT/f'gknu-{campus}-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 counts[campus]={'courses':len(courses),'scheduled':sum(bool(c['schedules']) for c in courses),'meetings':sum(len(c['schedules']) for c in courses)}
print(json.dumps(counts))
