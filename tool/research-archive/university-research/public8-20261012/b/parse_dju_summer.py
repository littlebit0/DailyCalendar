import pathlib,json,re,hashlib,openpyxl,collections
P=pathlib.Path(__file__).parent;f=next((P/'dju-summer-native').glob('*.xlsx'));w=openpyxl.load_workbook(f,data_only=True);courses=[];clock_ready=0
for r in w.worksheets[0].iter_rows(min_row=5,values_only=True):
 if not str(r[0]or'').isdigit():continue
 code=str(r[9]);section=str(r[11]);native=str(r[20]or'');room=' '.join(str(v)for v in r[21:23]if v and v!='미배정');slots=[];holds=['공식 2026.05.26 개설예정 목록: 6.2 확정/최종 폐강 공개 원자료 미확인']
 if r[1]in ['원격강좌','모듈교과목(온라인)','인턴십','사회봉사','군사훈련']:
  holds.append('원격/모듈/현장활동 배정시각: 실제 반복 대면수업 미확인')
 else:
  for day,periods in re.findall(r'([월화수목금토일])\(([^)]+)\)',native):
   ns=[int(x.strip())for x in periods.split(',')if x.strip().isdigit()]
   if not ns or any(x<1 or x>9 for x in ns):holds.append('공식 하계 1~9교시 표 밖 실제시각 미확인');slots=[];break
   slots.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':480+min(ns)*60,'endMinute':540+max(ns)*60,'classroom':room})
  if slots:clock_ready+=1
  else:holds.append('반복 요일/교시 미확인')
 courses.append(dict(sourceId=f'dju/main/2026/summer/{code}/{section}',universityId='dju',campus='main',academicYear=2026,semester='summer',courseCode=code,courseName=r[10],section=section,professor=r[16],credits=r[12],classification=r[2],departments=[],departmentCredits={},schedules=[],period={'startDate':'2026-06-23','endDate':'2026-07-13'},sourceSchedule=native,sourceClassroom=room,sourceEducation={'courseType':r[1],'nativeClockSchedulesBeforeOfferingConfirmation':slots,'academicDepartmentUnavailable':True,'lecturerIdOmitted':True},scheduleStatus='unrecognized',remarks='공식 개설예정 자료. 최종 개설/폐강 미확인.',holdReasons=list(dict.fromkeys(holds))))
j=dict(schemaVersion=2,universityId='dju',institutionId='dju',campus='main',campusName='본교',academicYear=2026,semester='summer',sourceUrl='https://www.dju.ac.kr/dju/na/ntt/selectNttInfo.do?nttSn=552054&bbsId=1861&mi=1165',retrievedDate='2026-10-12',observedDate='2026-10-12',publishedDate='2026-05-08',sourceUpdatedDate='2026-05-26',publishedDateUnavailable=False,periodSourceUrl='https://www.hanseo.ac.kr/boardCnts/fileDown.do?fileSeq=50219ca5fff706101c2dbc467e966881',sourceRowCount=len(courses),clockReadyRows=clock_ready,courseScheduleStatusCounts={'unrecognized':len(courses)},courses=courses,completionClaim=False,publishable=False,holdReason='Official notice and current attachment identify preliminary offerings; final confirmation/closures not public in inspected board.')
(P/'dju-main-2026-summer.held-candidate.json').write_text(json.dumps(j,ensure_ascii=False,indent=2));print('rows',len(courses),'clockReady',clock_ready)
