import copy,datetime as dt,hashlib,json,pathlib,re,shutil
p=pathlib.Path(__file__).parent;prior=p.parent/'nsu-regular-partial-20261008'
load=lambda f:json.loads(f.read_text())
base=load(pathlib.Path('assets/timetable/nsu-unknown-2026-2.json'))
assert len(base['courses'])==39 and sum(len(x['schedules']) for x in base['courses'])==255
(p/'baseline39-current-asset.json').write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
for name in ['own-guide-clock-calendar-education.json','pdf-independent-coordinate-education.json','nsu-clock-evidence.json']:
 shutil.copyfile(prior/name,p/name)
shutil.copyfile('/private/tmp/nsu-current-guide.pdf',p/'own-current-guide.pdf')
shutil.copyfile('/private/tmp/nsu-own-calendar-03.png',p/'own-calendar-page3-reading.png')
shutil.copyfile('/private/tmp/nsu-own-calendar-04.png',p/'own-calendar-page4-reading.png')
for name in ['nsu-arch-top-reading.png','nsu-arch-reading-crop.png','nsu-arch-bottom-reading.png','nsu-sfarm-reading-enlarged.png']:
 shutil.copyfile(pathlib.Path('/private/tmp')/name,p/name)
clock=load(p/'nsu-clock-evidence.json')['periods'];clocks={x['period']:(x['startMinutes'],x['endMinutes']) for x in clock}
assert [clocks[i] for i in range(1,10)]==[(540,590),(600,650),(660,710),(720,770),(780,830),(840,890),(900,950),(960,1010),(1020,1070)]
literal={1:['2026-08-31','2026-09-07','2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-10-19','2026-10-26','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07','2026-12-14'],2:['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-20','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01','2026-12-08','2026-12-15'],3:['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-21','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02','2026-12-09','2026-12-16'],4:['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-22','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-10','2026-12-17'],5:['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-23','2026-10-30','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04','2026-12-11','2026-12-18']}
excluded=['2026-09-24','2026-09-25','2026-10-05','2026-10-09']
actual={i:[] for i in range(1,6)};date=dt.date(2026,8,31)
while date<=dt.date(2026,12,19):
 if date.isoweekday()<=5 and date.isoformat() not in excluded:actual[date.isoweekday()].append(date.isoformat())
 date+=dt.timedelta(days=1)
assert literal==actual
note='남서울대 자체2026-2 수강편람 8/31개강·16주12/13~19·12/21방학과 공개 학과 정규시간표 기준입니다. 공개 공휴일 제외. 별도 시험 날짜·시간/집중·지정보강·최종 변경 미확인은 정규수업 계획과 구분하며 실제 보강은 만들지 않았습니다. 예배·경연·대동체전을 전교휴강으로 추정하지 않습니다. 과목코드·학점·구분·캠퍼스 미공개 유지, 실제 분반만 보존. 개별 최종 수강/변경/폐강합집합 보장은 하지 않습니다.'
c=copy.deepcopy(base);receipt=[]
for obj in c['courses']:
 old=copy.deepcopy(obj)
 if old['schedules']:
  expected=[]
  for date in sorted(set(x for v in literal.values() for x in v)):
   for r in obj['publicEducationCells']:
    if dt.date.fromisoformat(date).isoweekday()==r['weekday']:
     start,end=clocks[r['period']];expected.append({'date':date,'weekday':r['weekday'],'startMinute':start,'endMinute':end,'classroom':r['room'],'sourceRow':r['row'],'sourceColumn':r['column']})
  assert all(x in expected for x in old['schedules'])
  obj['schedules']=old['schedules']+[x for x in expected if x not in old['schedules']]
  assert len(obj['schedules'])==len(expected)
  obj['period']={'startDate':'2026-08-31','endDate':'2026-12-19'}
  obj['previousResearchRemarks']=old['remarks'];obj['remarks']=note
  assert all(obj[k]==old[k] for k in old if k not in ['schedules','period','remarks'])
 receipt.append({'sourceId':obj['sourceId'],'expectedPlans':obj['schedules'],'priorPlansExactRetained':len(old['schedules']),'newAdded':len(obj['schedules'])-len(old['schedules'])})
rows=load(p/'visual-image-literal-items.json')['items'];closures=load(p/'closure-2026-2-education.json')['rows'];norm=lambda s:re.sub(r'\s+','',s)
for r in rows:
 notice=load(p/('notice-102907.json' if r['noticeId']==102907 else 'recovered-103190.json'))
 department=notice['departmentScope'];file='notice-102907-file0.jpg' if r['noticeId']==102907 else 'notice-103190-image0.png'
 sourceurl='https://nsu.ac.kr'+notice['inlinePublicFilePaths'][0]
 teachers=list(dict.fromkeys(r['periodProfessors'].values()))
 matches=[x for x in closures if norm(x['courseName'])==norm(r['courseName']) and x['section']==r['section'] and norm(x['professor']) in [norm(v) for v in teachers]]
 plans=[]
 if not r['holdReason'] and not matches:
  for date in literal[r['weekday']]:
   for period in r['periods']:
    start,end=clocks[period]
    plans.append({'date':date,'weekday':r['weekday'],'startMinute':start,'endMinute':end,'classroom':r['room'],'sourcePeriod':period,'sourceGrade':r['grade'],'sourceBand':r['imageBand'],'sourceProfessor':r['periodProfessors'][str(period)]})
 obj={'sourceId':r['sourceId'],'sourceNoticeId':r['noticeId'],'sourcePublishedDate':notice['registered_date'].split(' ')[0],'sourceUrl':sourceurl,'referenceKind':'public image document grade/weekday/period/band locator, not official course code','canonicalSubjectCodePublished':False,'nativeSectionPublished':bool(r['section']),'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':r['section'],'courseName':r['courseName'],'professor':r['professor'],'credits':None,'classification':'','classificationGroup':'','departments':[f'{department} {r["grade"]}학년'],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'sourceSchedule':f'{r["weekday"]}요일 '+','.join(str(v) for v in r['periods'])+'교시','sourceClassroom':r['room'],'remarks':note,'publicImageEducation':r,'sourceImageSHA256':hashlib.sha256((p/file).read_bytes()).hexdigest(),'scheduleStatus':'scheduled' if plans else 'unrecognized','schedules':plans,'closureExactTitleSectionTeacherMatches':matches}
 if plans:obj['period']={'startDate':'2026-08-31','endDate':'2026-12-19'}
 else:obj['scheduleHoldReason']='exact published closure title/section/professor/native weekday-period match' if matches else r['holdReason']
 c['courses'].append(obj);receipt.append({'sourceId':obj['sourceId'],'sourceImage':file,'sourceLiteral':r,'expectedPlans':plans,'newAdded':len(plans)})
assert len({x['sourceId'] for x in c['courses']})==len(c['courses'])
c.update({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'semesterOrdinaryPlanOnly':True,'publishedExamOrMakeupPlansVerified':False})
(p/'nsu-unknown-2026-2.two-images-semester-v2.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
proof={'researchOnly':True,'completionClaim':False,'SDKExecuted':False,'metadata':len(c['courses']),'scheduled':sum(bool(x['schedules']) for x in c['courses']),'held':sum(not x['schedules'] for x in c['courses']),'meetings':sum(len(x['schedules']) for x in c['courses']),'prior39WholeSourceFieldsPreserved':True,'prior255ExactPlanObjectsRetained':True,'prior35ExpandedPlans':sum(len(x['schedules']) for x in c['courses'][:39]),'newImageItems':len(rows),'newClearImageItems':sum(bool(x['schedules']) for x in c['courses'][39:]),'newImageMeetings':sum(len(x['schedules']) for x in c['courses'][39:]),'literalDatesByWeekday':literal,'officialSchoolExcludedHolidays':excluded,'ordinarySemesterPeriod':['2026-08-31','2026-12-19'],'vacationStarts':'2026-12-21','eventDaysNotAssumedClosure':['2026-09-14','2026-09-29','2026-10-14'],'examDatesNotPublishedInOwnCalendar':True,'makeupMappingsUnverifiedGenerated0':True,'closure104ExactTitleSectionProfessorMatches':sum(bool(x.get('closureExactTitleSectionTeacherMatches')) for x in c['courses']),'closureUnionVerified':False,'nativeCodeJoinVerified':False,'proofByCourse':receipt}
(p/'literal-semester-source-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in proof.items() if k in ['metadata','scheduled','held','meetings','prior35ExpandedPlans','newImageItems','newClearImageItems','newImageMeetings']})
