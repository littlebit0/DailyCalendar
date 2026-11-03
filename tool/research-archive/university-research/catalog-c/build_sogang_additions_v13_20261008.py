"""Current twenty-offering review; literal dates and original numerical table words."""
import copy, datetime as dt, hashlib, json, re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent
O=R/'sogang-additions-v13-20261008'
B=R/'sogang-additions-v12-20261008/sogang-unknown-2026-2.one-hundred-ten-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[];held=[]
configs={
'CSE4330-01':(['09-24','10-20','10-22','12-14','12-15','12-17'],'CS/AI 학부 대상. source중간10/22 vs native10/20 충돌 둘다보류.9/24추석 및12/14보고서제출마감,12/15기말clock/12/17예비보강·리뷰조건미정 보류. 실제강의·실습 및15주발표/공개데모만. 기기대여는후속공지조건.'),
'EDUF981-01':(['09-24','10-20','10-22','10-29','12-08','12-10'],'학부실제nativeEDUF981.8주Online lecture 실제동시/녹화·배정시각미공개 보류;source10/29중간 vs native10/20 충돌보류.15주review/final 두날짜 실제배정미확인 보류.16주12/15·17 원문Final exam feedback 실제정규피드백만. 출석·readinglog·그룹발표 조건 원문보존.'),
'HFS2002-01':(['09-24','10-20','10-22','12-15','12-17'],'현재2026-2교육계획 원본날짜열좌표 독립대조.9/3·10·17 등추출연결된날짜 실제원문만. 8주10/20,22 및16주12/15,17 시험일개별배정미확인보류. 직접표시강의·조별토론만,선수필수과목없음·사전자료읽기·조별보고서조건보존.'),
'HFU4023-02':(['10-05','10-21','10-26','12-16','12-21'],'현재2026-2정확원문날짜좌표; 공통선택 native표현보존, broad분류추정없음.10/5공휴일,mid10/21,26·final12/16,21 시험실제개별배정미확인보류.10/19조별토론/12/9실제원문날짜보존, 토론과사전읽기조건.'),
'JAS4037-01':(['10-20','10-22','12-15','12-17'],'학부1~4. 원문9.3 및9/15,17 명시약식그대로날짜대조;source9/22단일수업만. mid10/20 or22·final12/15 or17 선택배정조건 보류; native단일시험만으로source선택조건해제안함. 북한미디어강의·분석 원문실제날짜만.'),
'LCS2003-01':(['10-05','10-21','10-26','12-16','12-21'],'현재2026-2/LCS2003-01/월수10:30~11:45. 원문PDF교실란공란과별도로 현재nativepublic교실J309명시 직접보존, 타분반교실추정안함.10/5공휴일·중간21/26·기말16/21배정미확인보류. 비초급자불이익 전분반동일조건·교재준비·발음/대화/문화발표조건보존. 문화발표날짜후속공지와정규시간표분리.'),
'LCS2003-05':([], '현재2026-2/LCS2003-05.1~5주 실제명시날짜만.9/18문화제운영미확인/9/25추석보류.6주이후본문4월·6월날짜 vs10월·12월표제충돌: 해당기간통째보류, 월자동교정안함. 비초급자불이익·사캠/ALLO워크북·조별발표조건보존.'),
'MGT4106-02':(['10-05','10-21','10-26','12-16','12-21'],'현재2026-2학부2~4. 실제regularPA201만;nativeexamPA201/PA203 개별실배정미공개로exam양쪽일 모두보류. 학교지정중간/기말요일·시각조건을상시수업으로추정안함.10/5공휴일. 스마트폰·웨어러블금지 등원문조건보존.'),
'MGT4502-01':(['09-10','09-22','09-24','10-22','12-15','12-17'],'현재Fall2026/MGT4502-01 실제Topic날짜열만.9/10·22 No in-person/Makeup ClassRecording 각mid/final전아무때나수강조건: 고정녹화시각추정안함.9/24NoClass·10/22StudyDay·12/15finalclock/12/17StudyDay보류.10/20source/public대면중간75분1회, 실제In-class그룹9/29·10/27·11/26 및liveinclass발표12/1·3·8·10대면override. 나머지원문일반강의·토론. 제출/모임/평가/녹음금지조건보존.'),
'MGT4711-02':(['09-24','10-20','10-22'],'현재2학기/MGT4711(02)/경영대학학부대상.9/24추석 및mid20/22시험일·범위사전공지미배정보류. 실제16주12/15·17 final teamproject발표·질의응답·동료/교수피드백 원문정규시간표범위보존, 별도기말시험추정안함. 외부전문가특강일후속공지·팀규모/시간조정조건보존.'),
'POL3184-01':(['09-18','09-25','10-09','10-21','10-23','11-20'],'현재native공개계획actual수금15~16:15D502. source주별날짜가휴일뒤이동한그대로보존, 학사표준주로변환안함.9/18festival운영미확인·9/25/10/9NoClass·11/20교내휴강. source중간21&23 배정미확인둘다보류,15주기말날짜미인쇄 미생성. Required/Recommended읽기·Finalreflectionpaper와실제수업날짜구분.'),
'SHS2002-04':(['09-28'],'현재2026-2/SHS2002/화목12~13:15. source9/28월요일 vs native화목충돌보류,9/29로교정안함. 원본표10/13/15숫자좌표로붙은추출해결.8주/16주시험날짜미인쇄미생성. 원문한국어강의·한국어강의곤란시비권장조건보존.'),
'SHS2005-04':(['09-24','10-20','10-22','12-15','12-17'],'현재2026-2/SHS2005/정확13:30~14:45분반시각. 추석24·중간20/22·기말15/17개별시험배정미확인보류. 진도변경·부교재읽기권장·출석도주/대리출석횟수별성적상한조건 원문보존.'),
'SHS2005-05':(['09-24','10-20','10-22','12-15','12-17'],'현재2026-2/SHS2005/정확15:00~16:15분반시각. 추석24·중간20/22·기말15/17개별시험배정미확인보류. 다른분반부교재2025 vs 본분반2023 원문각각유지. 진도변경·부교재읽기·출석도주/대리출석횟수별성적상한조건보존.'),
'SHS2012-01':(['09-24','10-20','10-22','12-15','12-17'],'현재2026-2/SHS2012. 원본9/8,10·10/27,29 명시같은월숫자토큰좌표로독립대조.추석24·mid20/22·final15/17개별시험배정미확인보류. 실제날짜강의·질의/토론·사례발표만;사전읽기와진도/관심따른변경조건.'),
'SOC3003-01':(['10-19','10-28','12-14'],'현재Aug3,2026원문updated/nativeSOC3003캡스톤. source명시매주2회대면inPerson모든날짜override.8~9주mid10/19/TBA및after-midterm party10/28배정·실제출석조건미확인보류.16주12/14,TBA finalclock미공개보류. 실제lecture/discussion/팀멘토링/프로젝트review/15주miniconference2회만; 월요일첫세션전reading·팀과제·절대평가·FA조건보존.')}
held_reasons={'CHU4024-01':'Currentnative CHU4024-01 vs printed CHU4003 reference conflict: all dates held, no guessed correction.','ENG2101-02':'Currentnative ENG2101-02 vs printed ENG2021-2 reference conflict: all dates held.','ENG3304-01':'Printed Spring(Semester2)2026 vs Fall2026 footer seasonal conflict: all dates held pending operation confirmation; no silent season correction.','SCE2104-01':'Only weekly date ranges published, no exact individual class dates proven; no automatic range expansion.'}
for key,reason in held_reasons.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];held.append({'offering':key,'reason':reason,'sourcePDFSHA256':s['fileSha256']})
geometry_keys={'HFS2002-01','HFU4023-02','SHS2002-04','SHS2012-01'}
for key,(excluded,note) in configs.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];text=s['weeklyOperatingText'].replace('\x00',' ');c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room_match=re.search(r'\[([^\]]+)\]',row['meetingText']);room=room_match[1] if room_match else '';assert end-start==75
 traces=[];date_sources={}
 if key in geometry_keys:
  g=json.loads((O/f'{key}.date-geometry.json').read_text());assert g['sourcePDFSha256']==s['fileSha256'];items=[(x['text'],x) for x in g['educationalDateTokens']]
 elif key=='MGT4502-01':items=[(m[1],None) for m in re.finditer(r'(?m)^(?:Topics\s+)?((?:9|10|11|12)/\d{1,2})\s*\((?:Tues|Thurs)\)',text)]
 else:items=[(text,None)]
 for value,token in items:
  for match in re.finditer(r'(\d{1,2})\s*[/.]\s*(\d{1,2})(?!\d)(?:,\s*(\d{1,2})(?![/.\d]))?',value):
   month=int(match[1]);days=[int(match[2])]+([int(match[3])] if match[3] else [])
   if month not in {9,10,11,12}:continue
   for day in days:
    date=dt.date(2026,month,day);ds=date.isoformat();date_sources[ds]=True
    if token:traces.append({'date':ds,'numericHeaderToken':token,'geometryFile':f'{key}.date-geometry.json'})
 allowed={'2026-09-02','2026-09-04','2026-09-09','2026-09-11','2026-09-16','2026-09-23','2026-09-30','2026-10-02'} if key=='LCS2003-05' else None
 holds=[];plans=[];weekdays={1,3} if key in {'HFU4023-02','LCS2003-01','MGT4106-02','SOC3003-01'} else ({3,5} if key in {'LCS2003-05','POL3184-01'} else {2,4});ex={'2026-'+x for x in excluded}|{'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}
 for ds in sorted(date_sources):
  date=dt.date.fromisoformat(ds)
  if ds in ex or (allowed is not None and ds not in allowed):holds.append({'date':ds,'reason':note});continue
  assert date.isoweekday() in weekdays and dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  plan={'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  if key=='SOC3003-01' or (key=='MGT4502-01' and ds in {'2026-09-29','2026-10-20','2026-10-27','2026-11-26','2026-12-01','2026-12-03','2026-12-08','2026-12-10'}):plan['deliveryMode']='inPerson'
  plans.append(plan)
 assert plans,key
 c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(plans),'attendanceConfirmed':False})
 if key=='HFU4023-02':c['sourceNativeClassification']='공통선택'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':len(plans),'nativeClock':row['meetingText'],'sourceDateGeometry':traces,'operatingNote':note});print(key,len(plans))
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==16
count=sum(len(c['schedules']) for c in out['courses']);scheduled=sum(bool(c['schedules']) for c in out['courses']);assert scheduled==126
f=O/'sogang-unknown-2026-2.one-hundred-twenty-six-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'reviewedNativeOfferings':20,'previousScheduled':110,'previousPlans':2712,'addedScheduled':16,'addedPlans':count-2712,'scheduled':scheduled,'plans':count,'changedOnly':changed,'proofs':proofs,'reviewedStillHeld':held,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(scheduled,count)
