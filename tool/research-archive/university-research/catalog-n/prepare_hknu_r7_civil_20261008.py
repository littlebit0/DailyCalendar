"""Current actual civil classroom grid, preserving native identities and original data."""
import json,pathlib,hashlib,copy,datetime as dt
R=pathlib.Path(__file__).resolve().parent
helper=(R/'prepare_hknu_r5_architecture_20261008.py').read_text();exec(helper[helper.index('ends={'):helper.index('files=[];audits=[]')])
# code, section, actual professor, weekday:first-last periods, actual classroom literal.
records=[('0000250002','A01','유선재',[(1,5,6,'201'),(3,5,5,'201')]),('0000250002','B01','유선재',[(1,13,15,'201')]),('0000250019','A01','최정호',[(4,1,3,'201')]),('0000250019','B01','최정호',[(1,10,12,'201')]),('0000250028','A01','권성우',[(1,5,8,'202')]),('0000250028','B01','권성우',[(1,10,12,'202')]),('0000250033','B01','유선재',[(2,10,12,'314')]),('0000250048','A01','김준성',[(2,5,5,'218'),(3,5,6,'218')]),('0000250048','B01','김준성',[(3,10,12,'218')]),('0000250084','A01','권성우',[(3,6,8,'201')]),('0000250084','B01','권성우',[(3,13,15,'201')]),('0000250104','A01','백성하',[(3,5,7,'202')]),('0000250105','A01','조성은',[(3,1,3,'201')]),('0000250105','B01','조성은',[(3,10,12,'201')]),('1000230021','A01','백성하',[(2,1,3,'201')]),('1000230021','B01','백성하',[(2,10,12,'201')]),('1000230022','A01','박병욱',[(1,7,7,'201'),(2,5,6,'201')]),('1000230022','B01','김종인',[(4,10,12,'201')]),('2002270005','A01','김준성',[(1,8,8,'201'),(2,7,8,'201')]),('2002270005','B01','김준성',[(2,13,15,'201')]),('2002270008','B01','백경오',[(1,13,15,'202')]),('2002270011','A01','유선재',[(2,1,3,'218')]),('0000250054','A01','조성은',[(1,2,3,'218'),(4,2,3,'218')]),('0000250054','B01','조성은',[(1,10,13,'218')]),('0000250078','A01','최정호',[(1,7,8,'218'),(3,7,8,'218')]),('0000250078','B01','최정호',[(1,15,15,'218'),(3,13,15,'218')]),('0000250082','A01','박병욱',[(1,5,6,'218'),(3,2,3,'218')]),('0000250082','B01','박병욱',[(1,14,14,'218'),(2,10,12,'218')]),('1000230014','A01','이정후',[(4,5,8,'218')]),('1000230014','B01','이정후',[(4,10,13,'218')]),('1000230015','A01','미정',[(2,6,9,'공동실험실습관401호')]),('1000230015','B01','미정',[(2,13,15,'공동실험실습관401호'),(4,14,14,'218')])]
night={10:(1080,1125),11:(1125,1170),12:(1175,1220),13:(1220,1265),14:(1270,1315),15:(1315,1360)};records_by={(code,sec):(prof,slots) for code,sec,prof,slots in records};assert len(records_by)==32
source='https://www.hknu.ac.kr/pdfView/hkce/120/hwpFileDownload.do';files=[];audit=[]
for campus in ['anseong','pyeongtaek']:
 original=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r6.json').read_text());d=copy.deepcopy(original)
 for c in d['courses']:
  if c['departments'][0]!='토목공학전공':continue
  c['metadata']['currentCivilPublishedEducationSource']={'sourceUrl':source,'readDate':'2026-10-08','sourceTitle':'2026-2 토목공학전공 시간표(요일별/학년별)','sourceEvidence':'hknu-current-civil-education-grid-coordinates-20261008.json','nativeSectionLinkedFromOriginalCodeDayNightUniqueOfferingNotInvented':True}
  c['departmentRemarks'][c['departments'][0]]+='\n공식 현재 토목 학생조건: 하위학년 수업 수강은 원칙 불허. 예외는 4학년 하위학년 재수강, 졸업학기 개설4학년 전체 수강에도 졸업학점 부족, 엇복학, 2학년부터 수강한 편입생. 주/야 변경은 설폐강 검토 후 허가, 4학년은4학년 과목 내 별도 제한 없음.'
  if '인성교육및상담' in c['courseName']:
   assert not c['schedules'];c['departmentRemarks'][c['departments'][0]]+='\n토목 상담 이수조건: 상담2회. 공시 시간에 상담하지 않으므로 교수와 개별 일정을 협의한 뒤 방문.';continue
  prof,slots=records_by[(c['courseCode'],c['section'])];weekly=[]
  for wd,first,last,room in slots:
   start=540+(first-1)*60 if first<10 else night[first][0];end=540+(last-1)*60+50 if last<10 else night[last][1]
   weekly.append({'weekday':wd,'startMinute':start,'endMinute':end,'classroom':room})
  c['professor']=prof;c['schedules']=dated(weekly);c['scheduleStatus']='scheduled';c['sourceClassroom']=' / '.join(dict.fromkeys(s['classroom'] for s in weekly));c['sourceSchedule']=' / '.join('('+['월','화','수','목','금','토','일'][s['weekday']-1]+') '+f"{s['startMinute']//60:02}:{s['startMinute']%60:02}~{s['endMinute']//60:02}:{s['endMinute']%60:02}" for s in weekly)
  c['metadata']['publishedWeeklyMeetingsUsedForPlan']=weekly;c['metadata']['currentCivilNativeIntegerPeriods']=[{'weekday':wd,'firstPeriod':first,'lastPeriod':last,'sourceRoomLiteral':room} for wd,first,last,room in slots];c['metadata']['currentClockDerivedOnlyFromActualCourseGridNotGlobalHalfPeriodInference']=True;c['metadata'].pop('partialClockOnlyConfirmedParts',None);c['metadata'].pop('unresolvedOtherPublishedMeetings',None)
  # Remove only earlier derived partial-support sentence, preserving source original education and all student conditions.
  c['departmentRemarks'][c['departments'][0]]=c['departmentRemarks'][c['departments'][0]].replace('\n공시 회의 중 확인된13–15.5 교시만 일부 추가. 다른 공시 회의 야간 소수 시각 미확정으로 제외, 전체 회의 완료가 아님.','')
  c['departmentRemarks'][c['departments'][0]]+='\n현재 토목 공식 개별 실제 셀의 정규 예정시각·교수·방 반영. 원본 야간 소수 교시를 전교 규칙으로 추정하지 않고 이 강좌의 실제 게시 integer 교시표만 사용.'
  if c['courseName']=='CAD':c['departmentRemarks'][c['departments'][0]]+='\n공식 CAD 주/야 수강인원 제한35명.'
  audit.append({'sourceId':c['sourceId'],'currentMeetings':len(c['schedules']),'currentProfessor':prof,'actualCells':c['metadata']['currentCivilNativeIntegerPeriods']})
 for a,b in zip(original['courses'],d['courses']):
  if a['departments'][0]!='토목공학전공':assert a==b
  for key in ['courseCode','section','sourceId','departments','departmentClassifications','departmentCredits']:assert a[key]==b[key]
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r7.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
assert len(audit)==32
m=json.loads((R/'hknu-planned-audited-20261008-r6-sha-manifest.json').read_text());m['files']=files;m['totalScheduledCount']=sum(x['scheduledCount'] for x in files);m['totalDateCount']=sum(x['dateCount'] for x in files);m['currentCivilWhole32RegularCourses8IndividualCounselingAudited']=True;m['currentCivilActualMeetingAudit']=audit
(R/'hknu-planned-audited-20261008-r7-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files)
