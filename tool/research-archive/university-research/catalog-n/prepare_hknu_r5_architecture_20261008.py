"""Apply actual current architecture tables by native section; no inferred offering."""
import json,pathlib,copy,hashlib,datetime as dt
R=pathlib.Path(__file__).resolve().parent
A='https://www.hknu.ac.kr/bbs/hkdesignarch/591/97327/artclView.do';E='https://www.hknu.ac.kr/bbs/hkdesignarch/295/97183/artclView.do'
# Each native published course cell was independently read with retained source coordinates.
# tuple: actual title, published native section, weekday, first/last actual PDF integer column, literal faculty, literal room.
a=[('한국건축사','A01',5,5,7,'신혜원','제3공학관 501호'),('건축구조역학','A01',3,5,7,'정호성','S501'),('건축법과제도','A01',2,1,3,'이희재','S413'),('건축시공계획','A01',5,1,3,'류형호','S413'),('건축의장학','A01',5,1,3,'김준경','S501'),('도시계획및설계','A01',2,1,3,'박광재','S501'),('디지털건축2','A01',2,5,7,'박선경','S314'),('건축구조계획','A01',4,1,3,'이영진','S413'),('환경친화건축','A01',1,1,3,'한창희','S413'),('시설프로그래밍','A01',3,1,3,'김성룡','S501'),('건축조형론','A01',2,1,4,'이승호','S522'),('디지털제도','A01',3,5,8,'허준영','S314'),('산업의료원Ⅳ','A01',6,1,5,'이을규','S501')]
for sec,prof,room in [('A01','허준영','R601'),('A02','이수경','R603'),('A03','이승호','R602')]:a.append(('기초설계2',sec,2,5,10,prof,room))
for title,sec,mon,thu,room in [('건축설계2','A01','김준경','류형호','R605'),('건축설계2','A02','조우성','김준경','R606'),('건축설계2','A03','성기창','성기창','R604'),('건축설계4','A01','박태상','서성직','R607'),('건축설계4','A02','김성룡','이민선','R607'),('건축설계6','A01','이희재','서한서','S522'),('건축설계6','A02','박광재','정현정','S515')]:
 a.extend([(title,sec,1,5,10,mon,room),(title,sec,4,5,10,thu,room)])
e=[('철근콘크리트구조1','A01',2,5,7,'주현진','S501'),('구조해석','A01',3,1,3,'정호성','S513'),('건설공정관리','A01',3,5,7,'김상철','S413'),('건축설비','A01',1,1,3,'안종훈','501'),('철골구조','A01',2,8,9,'조해창','S513'),('건설사업관리','A01',4,1,3,'김상철','S501'),('건축시공학2','A01',3,1,3,'김상철','S413'),('재료역학및실험','A01',4,1,3,'정호성','S513'),('건축실무디자인','A01',4,5,10,'권오상','S414-2'),('지역밀착형건축디자인의기초','A01',2,1,3,'안종훈','S414-1'),('빌딩시뮬레이션','A01',1,5,7,'안종훈','S513'),('건축공학종합설계2','A01',1,5,7,'주현진','S414-1'),('건축구조물전산해법','A01',2,4,7,'조해창','공실관203호')]
ends={1:'2026-12-21',2:'2026-12-08',3:'2026-12-09',4:'2026-12-17',5:'2026-12-18',6:'2026-12-19',7:'2026-12-21'};holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};extra={5:'2026-12-15',6:'2026-12-16'}
def dated(weekly):
 meetings=[]
 for s in weekly:
  day=dt.date(2026,9,1)
  while day<=dt.date.fromisoformat(ends[s['weekday']]):
   if day.isoweekday()==s['weekday'] and day.isoformat() not in holidays:meetings.append(dict(s,date=day.isoformat()))
   day+=dt.timedelta(days=1)
  if s['weekday'] in extra:
   date=extra[s['weekday']];meetings.append(dict(s,weekday=dt.date.fromisoformat(date).isoweekday(),date=date))
 return meetings
files=[];audits=[]
for campus in ['anseong','pyeongtaek']:
 original=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r3.json').read_text());d=copy.deepcopy(original)
 for dept,source,records in [('건축학전공',A,a),('건축공학전공',E,e)]:
  if campus!='anseong':continue
  group={}
  for rec in records:group.setdefault((rec[0],rec[1]),[]).append(rec)
  courses=[c for c in d['courses'] if c['departments'][0]==dept]
  for c in courses:
   c['metadata']['latestPublishedDepartmentOperatingSource']={'sourceUrl':source,'sourceModifiedDate':'2026-09-01' if dept=='건축학전공' else '2026-08-24','currentEducationGridEvidence':'hknu-current-'+('architecture' if dept=='건축학전공' else 'architectural-engineering')+'-education-grid-coordinates-20261008.json'}
   name=(c['courseName'],c['section']);recs=group.get(name)
   if recs:
    weekly=[]
    for title,section,wd,first,last,prof,room in recs:
     # Current PDF header posts exact clock of each integer column, including its own column10 18:00–18:50. Never generalized to other/night classes.
     start=540+(first-1)*60;end=540+(last-1)*60+50
     if title=='한국건축사':end=960 # current notice directly posts Friday13:00–16:00; body higher precision than printed15:50 grid last column.
     weekly.append({'weekday':wd,'startMinute':start,'endMinute':end,'classroom':room})
    c['schedules']=dated(weekly);c['scheduleStatus']='scheduled';c['professor']=' / '.join(dict.fromkeys(rec[5] for rec in recs));c['sourceSchedule']=' / '.join(f"({wd}) {540+(first-1)*60//1}-{540+(last-1)*60+50}" for _,_,wd,first,last,_,_ in recs);c['sourceClassroom']=' / '.join(dict.fromkeys(rec[6] for rec in recs))
    c['metadata']['currentPublishedDepartmentMeetingEducation']=[{'title':x[0],'section':x[1],'nativeWeekday':x[2],'actualPdfFirstIntegerColumn':x[3],'actualPdfLastIntegerColumn':x[4],'actualProfessor':x[5],'actualRoomLiteral':x[6]} for x in recs];c['metadata']['publishedWeeklyMeetingsUsedForPlan']=weekly
    c['departmentRemarks'][dept]+='\n현재 '+('9/1 건축학' if dept=='건축학전공' else '8/24 건축공학')+' 공식 시간표 셀의 실제 시각·교수·강의실 반영. 기호 S/R 강의실은 원문 그대로 표시, 원문 없는 건물 해석 미추가.'
   elif dept=='건축학전공' and '인성교육및상담' not in c['courseName']:
    c['schedules']=[];c['scheduleStatus']='unrecognized';reason='현재 첨부 시간표에 미게시; 본문은 첨부표 외 건축학 교과목 미개설 명시.'
    if c['courseName']=='자유교과목3':reason+=' 자유교과목은 별도 승인 후 전공 사무실 일괄신청 대상으로 현재 승인·개설 미확정.'
    if '건축설계8' in c['courseName']:reason='현재 표 담당 교수 자율 운영 명시; 개별 운영 시각·방 미확정. 원 게시 셀과 공동 교수 교육정보 보존.';c['metadata']['currentProfessorAutonomousOperations']={'A01':['이을규','김성룡'],'A02':['김준경','박광재','이희재']}[c['section']]
    c['metadata']['currentIndividualOperatingBlockReason']=reason;c['departmentRemarks'][dept]+='\n'+reason
   if dept=='건축학전공' and '설계' in c['courseName']:c['departmentRemarks'][dept]+='\n공식 학생조건: 설계 수업은 저번 학기와 같은 교수님 수강 불가. 특정 반 집중 방지로 개강 후 조정 가능. 분반 통합수업 장소는 1학년3공학관413, 2학년501, 3학년413, 4학년522로 공지되나 날짜별 통합 운영 여부 미게시라 정규 분반회의 방으로 덮지 않음.'
   if dept=='건축학전공' and c['courseName']=='건축조형론':c['departmentRemarks'][dept]+='\n공식 수강 제한: 건축조형론은 최대20명, 인원 증설 불가.'
   audits.append({'sourceId':c['sourceId'],'nativeTitle':c['courseName'],'nativeSection':c['section'],'currentMeetings':len(c['schedules']),'sourceUrl':source,'status':c['scheduleStatus']})
 # r4 civil-only safe partial proposal retained here; architecture自由 not restored.
 for c in d['courses']:
  if c['departments'][0]!='토목공학전공' or c['courseCode'] not in {'0000250078','1000230015'} or c['section']!='B01':continue
  wd=3 if c['courseCode']=='0000250078' else 2;weekly=[{'weekday':wd,'startMinute':1220,'endMinute':1360,'classroom':c['sourceClassroom']}];c['schedules']=dated(weekly);c['scheduleStatus']='scheduled';c['metadata']['publishedWeeklyMeetingsUsedForPlan']=weekly;c['metadata']['partialClockOnlyConfirmedParts']=True;c['metadata']['unresolvedOtherPublishedMeetings']=[{'originalPublishedRange':c['sourceSchedule'].split(' / ')[0 if wd==3 else 1],'reason':'야간 소수 교시 실제 clock 미확정'}];c['departmentRemarks'][c['departments'][0]]+='\n공시 회의 중 확인된13–15.5 교시만 일부 추가. 다른 공시 회의 야간 소수 시각 미확정으로 제외, 전체 회의 완료가 아님.'
 for old,new in zip(original['courses'],d['courses']):
  if old['departments'][0] not in ['건축학전공','건축공학전공'] and old['sourceId'] not in [c['sourceId'] for c in d['courses'] if c['metadata'].get('partialClockOnlyConfirmedParts')]:assert old==new
  for k in ['courseCode','section','departments','departmentClassifications','departmentCredits','sourceId']:assert old[k]==new[k]
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r5.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
m=json.loads((R/'hknu-planned-audited-20261008-r3-sha-manifest.json').read_text());m['files']=files;m['totalScheduledCount']=sum(x['scheduledCount'] for x in files);m['totalDateCount']=sum(x['dateCount'] for x in files);m['currentArchitectureWholeAffectedSourceOfferingAudit']=audits;m['nativeIdentityAndOriginalRawEducationUnchanged']=True;m.pop('allClocksDatesModesIdentitiesOtherEducationUnchangedFromR2',None)
(R/'hknu-planned-audited-20261008-r5-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files)
