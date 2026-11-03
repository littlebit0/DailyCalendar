"""Whole educational scope, six individually reviewed current ordinary plans.

Research-only. Generic registration clocks are not operating approval.
"""
import collections,datetime,hashlib,json,re
from pathlib import Path
from khu_educational_plan import clean_text
ROOT=Path(__file__).resolve().parent
rows=json.loads((ROOT/'khu-current-educational-rows-v2-20261008.json').read_text())
majors=json.loads((ROOT.parent/'catalogs/khu-major_202620.json').read_text());names={r['cd']:r['nm'] for r in majors if r['gb']=='H'}
category={'11':'전공기초','04':'전공필수','05':'전공선택','06':'교직과','14':'중핵교과','15':'배분이수교과','16':'기초교과','17':'자유이수','20':'교직전선','24':'계절학기전공필수','27':'계절학기전공기초','08':'일반선택'}
reviewed={'ICFI2004-01','ICFI2026-00','TRADE1016-00','TRADE2010-01','ICFI1002-01','SOC4040-00','TRADE4049-00','ECON1001-01','ECON3061-00','TRADE2048-00','TRADE3057-00','TRADE2056-00','ECON2042-00','ECON3052-00','ICFI1001-00','TRADE1001-01','ECON3063-00','ECON2042-01','ECON3003-00','ECON1003-00','ECON3033-00','SOC2006-00','TRADE4044-00','ECON1002-02','ECON2003-00','ICFI3025-00','TRADE2003-00','SOC4042-00','SOC2018-00'}
exact={'ECON1001-00':[('2026-10-20',1080,1140,'','inPerson'),('2026-12-15',1080,1140,'','inPerson')], 'ICFI4035-00':[('2026-09-05',960,1125,'정305','inPerson'),('2026-10-17',960,1125,'정305','inPerson'),('2026-10-24',960,1050,'','inPerson'),('2026-12-05',960,1125,'','liveOnline'),('2026-12-12',960,1050,'','inPerson')]}
plans=collections.defaultdict(list)
for file in (ROOT/'public-plans-v2').glob('*.json'):
 p=json.loads(file.read_text());plans[(p['campus'],p['lectureCode'])].append(p)
groups=collections.defaultdict(list)
for r in rows:groups[(r['campus_nm'],r['lecture_cd'])].append(r)
weekdays={c:i+1 for i,c in enumerate('월화수목금토일')}
slotpattern=re.compile(r'([월화수목금토일])\s+(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\((.*?)\)(?=\s*(?:<BR>|$))')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
courses=collections.defaultdict(list);decisions=[]
for (nativecampus,code),variants in groups.items():
 campus={'서울':'seoul','국제':'global'}[nativecampus]
 display={r['lecture_cd_disp'] for r in variants};assert len(display)==1;display=next(iter(display));subject,section=display.rsplit('-',1)
 deps={r['queryDepartmentName'] for r in variants};classes={r['queryDepartmentName']:category[r['field_gb']] for r in variants}
 credits={dep:{float(r['unit_num']) for r in variants if r['queryDepartmentName']==dep} for dep in deps};assert all(len(v)==1 for v in credits.values());credits={k:next(iter(v)) for k,v in credits.items()}
 titles=list(dict.fromkeys(r['subjt_name'] for r in variants));teachers=list(dict.fromkeys(r['teach_na'] for r in variants));sourceTimes=list(dict.fromkeys(r['timetable'] for r in variants));rawslots=[]
 for text in sourceTimes:
  for day,sh,sm,eh,em,room in slotpattern.findall(text):
   start=int(sh)*60+int(sm);end=int(eh)*60+int(em)
   if end>start:rawslots.append((weekdays[day],start,end,room))
 rawslots=list(dict.fromkeys(rawslots));schedules=[];notes=[];ownplans=plans[(nativecampus,code)]
 status='unrecognized' if rawslots or any(re.search(r'\d{2}:\d{2}',t) for t in sourceTimes) else 'unscheduled'
 if display in reviewed or display in exact:
  assert ownplans and {p['queriedProfessorName'] for p in ownplans}==set(teachers)
  assert len(ownplans)==1
  plan=ownplans[0];weeks=next(s['rows'] for s in plan['educationalSections'] if s['section']=='주별강의내용');ordinary=[]
  for row in weeks:
   if len(row)<4 or not re.fullmatch(r'\d+주',row[0]):continue
   # Empty/actual exam windows do not create attendance at an invented exam clock.
   if display=='SOC2006-00' and row[0]=='16주':continue
   if display=='TRADE2003-00' and row[0] in ['5주','6주','7주','15주']:continue
   if row[2].strip().lower() in {'final','midterm'}:continue
   if not row[2].strip() or re.search(r'중간고사|기말고사|시험|\bmid[- ]?term\b|\bfinal exam(?:ination)?\b|\bterm end exam\b|\bexam(?:ination)?\b|\bfinal\s*$',row[2]+' '+row[3],re.I):continue
   match=re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',row[1]);assert match
   a,b,c,d=map(int,match.groups());ordinary.append((datetime.date(2026,a,b),datetime.date(2026,c,d)))
  for weekday,start,end,room in (rawslots if display not in exact else []):
   day=datetime.date(2026,9,1)
   while day<=datetime.date(2026,12,21):
    if day.isoweekday()==weekday and day.isoformat() not in closed and any(a<=day<=b for a,b in ordinary):
     if display=='TRADE3057-00' and day.isoformat() in {'2026-09-24','2026-10-01'}:
      day+=datetime.timedelta(days=1);continue
     schedules.append({'date':day.isoformat(),'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room})
    day+=datetime.timedelta(days=1)
  if display in exact:
   for date,start,end,room,mode in exact[display]:
    schedules.append({'date':date,'weekday':datetime.date.fromisoformat(date).isoweekday(),'startMinute':start,'endMinute':end,'classroom':room,'deliveryMode':mode})
  for s in plan['educationalSections']:
   if s['section'] in ['선수과목','수업운영방식']:
    source=s['rows'] if s['section']=='선수과목' else s['rows'][1:]
    notes.extend(' / '.join(r) for r in source if any(r) and '조회된 데이터가 존재하지 않습니다.' not in r)
   if s['section']=='주별강의내용':
    notes.extend('학교 수업 계획: '+' / '.join(r) for r in s['rows'] if r and re.fullmatch(r'\d+주',r[0]) and re.search(r'시험|고사|midterm|final|recorded lecture|최종보고서 제출', ' '.join(r[2:]), re.I))
   if s['section']=='주별강의내용':notes.extend(' / '.join(r) for r in s['rows'] if r and r[0] in ['기타','과제','수업안내사항'] and any(r[1:]))
  if display=='TRADE2003-00':notes.append('5·6주차 휴일·변경 예정 안내가 실제 달력 주차와 일치하지 않아 해당 주차는 보류합니다. 7·15주차는 개별 질의응답으로 학생별 배정이 확인되지 않아 출석 시각을 만들지 않습니다. 해당 날짜의 수업 방법과 개인 배정은 담당교수 안내를 확인하세요.')
  if display=='TRADE3057-00':notes.append('4주차9월24일과5주차10월1일은 학교 계획에 녹화 수업으로 표시되어 있습니다. 해당 날짜만 시간표에서 제외하며, 비정기 영상 수업은 일반 주간 출석 시각으로 만들지 않습니다.')
  if display not in exact:notes.append('학교가 공개한 정규 수업 계획입니다. 실제 시간 변경이나 참석을 확인한 정보가 아닙니다. 게시된 휴일과 빈 주차·시험 주차는 제외했으며, 시험 시각과 대체 수업은 별도로 만들지 않았습니다.')
  if display in exact:notes.append('비정기 영상 수업은 일반 주간 시간표로 만들지 않습니다. 공개 계획에 날짜와 시간이 명시된 대면 수업·시험 및 실시간 온라인 수업만 반영합니다. 미게시 시험 강의실과 온라인 강의실은 빈값입니다. 실제 출석이나 향후 계획 변경을 확인한 정보가 아닙니다.')
  status='scheduled';decisions.append({'displayCode':display,'campus':campus,'plannedDates':len(schedules),'actualAttendanceConfirmed':False,'currentPlanHeaderVerified':True})
 else:notes.append('강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.')
 if len(titles)>1:notes.append('학교 자료의 다른 과목명 표기: '+' / '.join(titles))
 remarks={dep:'\n'.join(dict.fromkeys([clean_text(r['bigo']) for r in variants if r['queryDepartmentName']==dep and r['bigo'].strip()]+notes)) for dep in deps}
 course={'sourceId':f'khu/2026/2/{campus}/{code}','campus':campus,'academicYear':2026,'semester':'2','courseCode':subject,'section':section,'courseName':titles[0],'courseNameAliases':titles[1:],'professor':' / '.join(teachers),'credits':next(iter(set(credits.values()))) if len(set(credits.values()))==1 else None,'departments':sorted(deps),'departmentCredits':credits,'departmentClassifications':classes,'departmentRemarks':remarks,'sourceSchedule':re.sub(r'<br\s*/?>','\n','\n'.join(sourceTimes),flags=re.I),'sourceClassroom':' / '.join(dict.fromkeys(s[3] for s in rawslots if s[3])),'scheduleStatus':status,'schedules':schedules,'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},'sourceEducationalVariants':[{**r,'bigo':clean_text(r['bigo'])} for r in variants],'sourceOpeningDepartment':names[variants[0]['class_cd']]}
 courses[campus].append(course)
assert len(groups)==4666 and len(decisions)==31
manifest={'completionClaim':False,'productionRegistered':False,'wholePublicCurrentCollection':True,'wholeOperatingReviewComplete':False,'datasets':[],'decisions':decisions}
for campus,cs in courses.items():
 data={'schemaVersion':2,'universityId':'khu','campus':campus,'campusName':{'seoul':'서울','global':'국제'}[campus],'academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu','researchOnly':True,'actualAttendanceConfirmed':False,'courses':cs}
 name=f'khu-{campus}-2026-2.thirtyone-reviewed-next-20261008.json';b=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();(ROOT/name).write_bytes(b);manifest['datasets'].append({'file':name,'sha256':hashlib.sha256(b).hexdigest(),'courses':len(cs),'scheduled':sum(c['scheduleStatus']=='scheduled' for c in cs),'untimed':sum(c['scheduleStatus']=='unscheduled' for c in cs),'held':sum(c['scheduleStatus']=='unrecognized' for c in cs),'datedMeetings':sum(len(c['schedules']) for c in cs)})
(ROOT/'khu-thirtyone-reviewed-next-manifest-20261008.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(manifest)
