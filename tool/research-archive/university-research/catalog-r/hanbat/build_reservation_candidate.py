"""Official current UG plans; native campus and actual clock preserved."""
import collections,datetime as dt,json,re
from pathlib import Path
R=Path(__file__).parent
raw=json.loads((R/'hanbat-current-2026-2-native-education-rows-v1.json').read_text())
week={i:((8+i)*60,(8+i)*60+50) for i in range(1,10)};week.update({10:(1120,1170),11:(1175,1225),12:(1230,1280),13:(1290,1340)})
sat={i:((8+i)*60,(8+i)*60+50) for i in range(1,6)};sat.update({6:(840,890),7:(895,945),8:(950,1000),9:(1005,1055),10:(1060,1110),11:(1115,1165),12:(1170,1220),13:(1225,1275)})
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026-09-04 공식 제2차 개설·폐강 확정 목록의 원래 캠퍼스·강좌번호·과목코드·분반·이수구분·교수·강의실을 보존합니다. 이후 개별 변경은 별도 확인해야 합니다. 주중과 토요일 교시는 공식 수업 안내의 서로 다른 실제 시각을 적용합니다. 수업 방식은 미지정으로 사용자가 선택한 대면·원격·동영상 방식을 유지합니다. 공개 15주 수업기간은 9월 1일~12월 14일이며 보강주는 12월 15일~21일입니다. 보강·시험의 개별 일정은 생성하지 않았습니다. 담당교수별 일정이 다를 수 있습니다.'
counts={};why=collections.Counter()
for campus,native in [('daejeon','대전'),('sejong','세종')]:
 courses=[]
 for r in raw['rows']:
  if r['campus']!=native:continue
  reason='';spans=[]
  if r['operatingStatus']!='개설':reason='공식 확정 폐강'
  elif any(s in str(r['title'])+' '+str(r['rawRoom']) for s in ['이러닝','온라인','MOOC','현장실습','사회봉사','군복무']):reason='원격·현장·봉사 운영 날짜 미확인'
  elif not r['rawRoom']:reason='개별 강의실 미확인'
  elif '.' in str(r['rawSchedule']):reason='분수 교시 실제 시작·종료 시각 미확인'
  else:
   text=str(r['rawSchedule']).replace(' ','');matches=list(re.finditer(r'([월화수목금토일])([^월화수목금토일]+)',text));rooms=str(r['rawRoom']).split(',')
   if not matches or ''.join(m[0] for m in matches)!=text:reason='교시 표기 미확인'
   elif len(rooms) not in [1,len(matches)]:reason='원본 교시와 강의실 대응 미확인'
   else:
    for j,m in enumerate(matches):
     day='월화수목금토일'.index(m[1])+1;room=rooms[0 if len(rooms)==1 else j];ps=m[2].strip(',').split(',')
     if day==7 or not all(p.isdigit() and 1<=int(p)<=13 for p in ps):reason='공식 시각 범위 밖 교시';break
     clock=sat if day==6 else week
     # Keep each printed period separately; breaks and room changes remain exact.
     spans += [dict(weekday=day,startMinute=clock[int(p)][0],endMinute=clock[int(p)][1],classroom=room) for p in ps]
  meetings=[]
  if not reason:
   d=dt.date(2026,9,1)
   while d<=dt.date(2026,12,14):
    if d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
     meetings += [dict(s,date=d.isoformat()) for s in spans if s['weekday']==d.isoweekday()]
    d+=dt.timedelta(days=1)
  else:why[reason]+=1
  credit=float(r['credits']);department=r['openingDepartment'];classification=r['classification'] or ''
  courses.append(dict(sourceId=f"hanbat/{campus}/2026-2/{r['nativeLectureId']}",campus=campus,academicYear=2026,semester='2',courseCode=r['nativeCourseCode'],courseName=r['title'],section=r['nativeSection'],professor=r['professors'] or r['representativeProfessor'] or '',classification=classification,credits=credit,departments=[department],departmentCredits={department:credit},departmentClassifications={department:classification},remarks=notes+' 원본 편성·전공이수체계·주야·학년: '+str(r['formation'])+'/'+str(r['majorSystem'])+'/'+str(r['dayNight'])+'/'+str(r['grade'])+(' 예약 보류: '+reason if reason else ''),sourceSchedule=str(r['rawSchedule']),sourceClassroom=r['rawRoom'] or '',scheduleStatus='scheduled' if meetings else 'unrecognized',schedules=meetings,period=dict(startDate='2026-09-01',endDate='2026-12-21'),metadata=dict(originalEducationalFields=r,researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,wholeLatestChangesConfirmed=False,deliveryModeStatus='unknown-user-choice',heldReason=reason,campusScope='Exactpublishednativecampus',clockScope='OfficialweekdayorSaturdayUGtable')))
 data=dict(schemaVersion=2,universityId='hanbat',campus=campus,campusName=native,academicYear=2026,semester='2',publishedDate='2026-09-04',sourceUrl=raw['sourceUrl'],researchOnly=True,completionClaim=False,courses=courses)
 (R/f'hanbat-{campus}-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');counts[campus]=dict(rows=len(courses),scheduled=sum(bool(c['schedules']) for c in courses),meetings=sum(len(c['schedules']) for c in courses))
print(json.dumps(dict(counts=counts,held=why),ensure_ascii=False))
