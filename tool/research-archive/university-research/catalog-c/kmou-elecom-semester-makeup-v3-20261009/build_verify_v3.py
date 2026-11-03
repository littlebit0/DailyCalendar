import copy, datetime as dt, hashlib, json, pathlib, re, shutil
p=pathlib.Path(__file__).parent
v2=p.parent/'kmou-elecom-current-public-grid-v2-20261009'
old=p.parent/'kmou-current-20261008'
load=lambda x:json.loads(x.read_text())
base=load(p/'prior13-current-asset-snapshot.json')
c=load(v2/'kmou-unknown-2026-2.elecom-partial-v2.json')
raw=load(p/'current2026-2-revised-grid.hwp.tables.json')[0]
oldraw=load(old/'source-educational-tables.json')
calendar=load(old/'calendar-operating-education.json')
closure=load(old/'closure-education.json')
makeup=load(p/'kmou-makeup.hwp.tables.json')[0]['tables'][1]['cells']
mapping=[('2026-09-24','2026-12-10'),('2026-09-25','2026-12-11'),('2026-10-05','2026-12-14'),('2026-10-09','2026-12-08'),('2026-11-05','2026-12-09')]
for row,(before,after) in enumerate(mapping,1):
 for col,date in [(1,before),(2,after)]:
  txt=next(v for v in makeup if v['row']==row and v['column']==col)['paragraphs'][0]
  nums=[int(x) for x in re.findall(r'\d+',txt)]
  assert nums==[int(date[5:7]),int(date[8:])]
  assert '월화수목금토일'[dt.date.fromisoformat(date).weekday()] in txt
literal={1:['2026-09-07','2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-10-19','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07','2026-12-14'],2:['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01'],3:['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02'],4:['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-29','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-09','2026-12-10']}
byday={}
for wd in range(1,6):
 dates=[];d=dt.date(2026,9,1)
 while d<=dt.date(2026,12,7):
  if d.isoweekday()==wd and d.isoformat() not in dict(mapping) and not(dt.date(2026,10,20)<=d<=dt.date(2026,10,26)):dates.append(d.isoformat())
  d+=dt.timedelta(days=1)
 dates += [after for before,after in mapping if dt.date.fromisoformat(before).isoweekday()==wd]
 byday[wd]=sorted(dates)
 if wd<=4:assert byday[wd]==literal[wd]
proof=[]
for i,course in enumerate(c['courses']):
 prior=copy.deepcopy(course)
 cells=course.get('publicEducationCells')
 if cells:
  records=[]
  for cell in cells:
   assert oldraw['tables'][cell['table']][cell['row']][cell['column']]==cell['text']
   assert oldraw['tables'][cell['table']][cell['row']][0]==cell['clockText']
   records.append({'table':cell['table'],'row':cell['row'],'column':cell['column'],'weekday':cell['weekday'],'clockText':cell['clockText'],'room':cell['room']})
 else:
  e=course['sourceEducation'];t=raw['tables'][e['table']]
  native=next(v for v in t['cells'] if (v['row'],v['column'])==(e['row'],e['column']))
  assert native['paragraphs']==e['nativeParagraphs']
  records=[{'table':e['table'],'row':x['period'],'column':e['column'],'weekday':e['column'],'clockText':x['clockText'],'room':x['classroom']} for x in e['nativeClockPeriods']]
 expected=[]
 for r in records:
  nums=[int(x) for x in re.findall(r'\d+',r['clockText'])];offset=720 if r['row']>=5 else 0
  start=nums[1]*60+nums[2]+offset;end=nums[3]*60+nums[4]+offset
  assert end-start==50
  for date in literal[r['weekday']]:
   actual=dt.date.fromisoformat(date).isoweekday()
   plan={'date':date,'weekday':actual,'startMinute':start,'endMinute':end,'classroom':r['room'],'sourceTable':r['table'],'sourceRow':r['row'],'sourceColumn':r['column']}
   mapped=[before for before,after in mapping if after==date and dt.date.fromisoformat(before).isoweekday()==r['weekday']]
   if mapped:plan.update({'sourceWeekday':r['weekday'],'makeupForDate':mapped[0],'scheduleKind':'publishedMakeup'})
   else:assert actual==r['weekday']
   expected.append(plan)
 # Retain every original schedule object and append only genuinely new dates/slots.
 key=lambda s:(s['date'],s['startMinute'],s['endMinute'],s['classroom'],s['sourceTable'],s['sourceRow'],s['sourceColumn'])
 oldkeys={key(s) for s in prior['schedules']};expectedkeys={key(s) for s in expected}
 assert oldkeys<=expectedkeys
 course['schedules']=prior['schedules']+[s for s in expected if key(s) not in oldkeys]
 assert len({key(s) for s in course['schedules']})==len(expected)
 assert {key(s) for s in course['schedules']}==expectedkeys
 course['period']={'startDate':'2026-09-01','endDate':'2026-12-14'}
 course['previousResearchRemarks']=prior['remarks']
 course['remarks']='공식 공개 확인용 시간표. 최종 시간·장소는 종합정보시스템 확인 필요. 자체 2026-2 개강 9/1~12/7 정규수업(10/20~26 중간시험·공식 휴일 제외), 12/8~14 학교 지정보강 중 해당 원래 요일 매핑만 추가. 과목코드·개별 분반·학점·구분·캠퍼스 미공개 그대로 보존. 개별 최종 변경·시험 강의는 추정하지 않음.'
 assert all(course[k]==prior[k] for k in prior if k not in ['schedules','period','remarks'])
 assert not [x for x in closure['courses'] if re.sub(r'\s+','',x['courseName'])==re.sub(r'\s+','',course['courseName'])]
 proof.append({'sourceId':course['sourceId'],'sourceRecords':records,'literalExpected':expected,'oldSchedulesPreserved':len(prior['schedules']),'newSchedulesAdded':len(expected)-len(prior['schedules'])})
assert sum(len(x['schedules']) for x in c['courses'][:13])==507
assert sum(len(x['schedules']) for x in c['courses'][13:])==689
assert sum(len(x['schedules']) for x in c['courses'])==1196
c['researchOnly']=True;c['productionIntegrationEnabled']=False;c['completionClaim']=False
(p/'kmou-unknown-2026-2.semester-makeup-v3.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
report={'researchOnly':True,'completionClaim':False,'SDKExecuted':False,'totalItems':30,'totalMeetings':1196,'prior13MeetingsExpanded':507,'new17Meetings':689,'prior179ExactScheduleObjectsPreserved':True,'priorFieldsPreservedExceptExplicitPeriodAndRemarks':True,'priorExamOrHolidayContradictions':0,'ordinaryWindow':['2026-09-01','2026-12-07'],'midtermExcluded':['2026-10-20','2026-10-26'],'makeupWindow':['2026-12-08','2026-12-14'],'finalExamExcluded':['2026-12-15','2026-12-21'],'winterVacationStarts':'2026-12-22','literalDatesBySourceWeekday':literal,'mapping':mapping,'sourceWeekdayAndActualWeekdaySeparated':True,'all1196LiteralChecksPassed':True,'closedTitleExactMatches':0,'nativeCodeSectionJoinVerified':False,'finalSystemWarningRetained':True,'proofByCourse':proof,'calendarPDF_SHA256':hashlib.sha256((p/'kmou-2026-calendar-fresh.pdf').read_bytes()).hexdigest(),'makeupHWP_SHA256':hashlib.sha256((p/'kmou-makeup.hwp').read_bytes()).hexdigest()}
assert report['calendarPDF_SHA256']==calendar['sha256']
(p/'independent-semester-literal-proof.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(old/'source-educational-tables.json',p/'prior13-source-educational-tables.json')
print('30/1196; old13 507 incl exact prior179; new17 689; literal checks pass')
