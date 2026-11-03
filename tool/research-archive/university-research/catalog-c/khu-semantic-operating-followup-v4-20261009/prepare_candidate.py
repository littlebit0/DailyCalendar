import copy,datetime as dt,hashlib,json,re
from pathlib import Path
OUT=Path(__file__).parent;OLD=OUT.parent/'khu-semantic-operating-followup-v3-20261009'
review=json.loads((OUT/'individual-neutral-operating-review.json').read_text());KEYS={(x['code'],x['section']) for x in review['decisions'] if x['selected']}
screen=json.loads((OUT.parent/'khu-ordinary-reservation-v2-20261008/current-native-operating-screen.json').read_text());decisions={x['sourceId']:x for x in screen['decisions'] if (x['courseCode'],x['section']) in KEYS}
assert len(decisions)==43 and all(x['screenReasons']==['currentPlanExplicitRemoteOperation'] for x in decisions.values())
SLOT=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
EX=re.compile(r'시험|고사|추석|공휴일|연휴|휴강|휴일|midterm|final\s*(exam|test)|no\s*class|holiday|vacation',re.I)
INT=re.compile(r'비실시간|비대면|실시간|온라인|원격|녹화|동영상|블[렌랜]디드|하이브리드|blended|flipped|asynchronous|online|remote|recorded|MOOC',re.I)
CLOSED={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};START=dt.date(2026,9,1);END=dt.date(2026,12,21)
proofs=[];inputs={};totals=[]
CALENDAR=OUT.parents[1]/'catalog-u/khu-current-calendar-period-proof-20261008.json'
inputs[str(CALENDAR)]=hashlib.sha256(CALENDAR.read_bytes()).hexdigest()
calendar=json.loads(CALENDAR.read_text())
assert calendar['checkedAt']=='2026-10-08'
assert any('9. 1.(화)' in row and '개강 (학기 개시일)' in row for row in calendar['relevantRows'])
assert any('12.22.(화)' in row and '동계 방학' in row for row in calendar['relevantRows'])
for campus in ['seoul','global']:
 oldp=OLD/f'khu-{campus}-2026-2.semantic-operating-research-v3-20261009.json';b=oldp.read_bytes();inputs[str(oldp)]=hashlib.sha256(b).hexdigest();old=json.loads(b);new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in decisions:continue
  assert not c['schedules'];decision=decisions[c['sourceId']];exclusions=[(dt.date(2026,10,20),dt.date(2026,10,26)),(dt.date(2026,12,15),dt.date(2026,12,21))];exceptionrows=[];signals=[];sourceproofs=[]
  variants=c['sourceEducationalVariants'];teachers={v['teach_na'] for v in variants}
  for pr in decision['planProofs']:
   p=Path(pr['file']);plan=json.loads(p.read_text());assert plan['lectureCode']==variants[0]['lecture_cd'];assert plan['queriedProfessorName'] in teachers;assert plan['header']==['2026학년도 2학기 강의계획서'];inputs[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
   sourceproofs.append({'file':str(p),'SHA256':inputs[str(p)],'nativeLectureCode':plan['lectureCode'],'nativeProfessor':plan['queriedProfessorName']})
   for s in plan['educationalSections']:
    for row in s['rows']:
     if not row:continue
     if s['section'] in ['수업운영방식','수업유형 및 방법','주별강의내용']:
      text=' '.join(row[2:] if s['section']=='주별강의내용' else row[1:])
      if INT.search(text):signals.append({'file':str(p),'section':s['section'],'originalRow':row,'meaning':'Realtime classroom pedagogy/practice/content topic or Nonlinear English substring is not an explicit remote delivery calendar.'})
     if s['section']=='주별강의내용' and len(row)>=3 and re.fullmatch(r'\d+주',row[0]) and EX.search(' '.join(row[2:])):
      r=re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',row[1]);assert r,(c['sourceId'],row)
      a,b,z,d=map(int,r.groups());first,last=dt.date(2026,a,b),dt.date(2026,z,d);assert START<=first<=last<=END
      exclusions.append((first,last));exceptionrows.append({'file':str(p),'originalRow':row,'dates':[first.isoformat(),last.isoformat()]})
  assert signals
  slots=[]
  for m in SLOT.finditer(c['sourceSchedule']):slots.append(('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()))
  assert slots and all(0<=a<b<=1440 and room for _,a,b,room in slots)
  meetings=[]
  for weekday,a,b,room in slots:
   day=START
   while day<=END:
    if day.isoweekday()==weekday and day.isoformat() not in CLOSED and not any(x<=day<=y for x,y in exclusions):meetings.append({'date':day.isoformat(),'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room})
    day+=dt.timedelta(days=1)
  assert meetings
  c['schedules']=meetings;c['scheduleStatus']='scheduled'
  note='현재 2026-2 원문의 실시간 대면·교실 피드백·실시간 기술 주제 및 Nonlinear의 online 부분 문자열은 원격 수업 운영 근거가 아닙니다. 공개 정규 요일·HH:mm·강의실의 학교 자체 기간 내 예약 계획이며 실제 출석·날짜별 운영·최신 폐강 완료가 아닙니다. 명시 시험주·휴일·원문 날짜별 시험 범위는 예약 제외하고, 교수법/대면 원문은 보존하되 날짜별 확정 운영이 아닌 사용자 방식 3종은 유지합니다.'
  c['departmentRemarks']={k:v+'\n'+note for k,v in c['departmentRemarks'].items()}
  c['semanticOperatingReview']={'priorHoldReason':'currentPlanExplicitRemoteOperation','correctedMeaning':'Realtime pedagogy/content and Nonlinear substring are not remote delivery.','individualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','newSourceChangeClaim':False}
  proofs.append({'sourceId':c['sourceId'],'courseCode':c['courseCode'],'section':c['section'],'professor':c['professor'],'campus':campus,'sourceSchedule':c['sourceSchedule'],'sourceClassroom':c['sourceClassroom'],'sourceProofs':sourceproofs,'semanticOriginalRows':signals,'examHolidayOriginalRows':exceptionrows,'newDates':len(meetings)})
 original={c['sourceId']:c for c in old['courses']};assert all(c==original[c['sourceId']] for c in new['courses'] if c['sourceId'] not in decisions)
 new.update({'researchOnly':True,'completionClaim':False,'semanticReviewRevision':'v4-20261009','actualModelValidationPending':True})
 p=OUT/f'khu-{campus}-2026-2.semantic-operating-research-v4-20261009.json';p.write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');totals.append({'campus':campus,'nativeObjects':len(new['courses']),'scheduled':sum(bool(c['schedules']) for c in new['courses']),'meetings':sum(len(c['schedules']) for c in new['courses']),'file':p.name})
assert len(proofs)==43
receipt={'researchOnly':True,'completionClaim':False,'impossibleClaim':False,'sdkUsed':False,'productChanged':False,'actualModelValidationPending':True,'sourceSnapshot':'2026-10-08','newCurrentSourceCollectionClaim':False,'scheduledAdded':43,'datesAdded':sum(x['newDates'] for x in proofs),'priorAll4666NativeAnd1858ScheduledPreserved':True,'prior66SelectedOnlineCorrectionsRetained':True,'datasets':totals,'proofs':proofs,'inputSHA256':inputs,'explicitHeldPreserved':['Actualwinterintensive PE1012-02','Externalpublicart GEE11007','PSC3029 laterexternalpublicdiplomacyevents','ART1212 actualexhibitionvisits','FDA201 explicitpotentialfieldlecture','KMS2220 medicalweek-specificoperationnotreviewed'],'ownPeriodProof':{'file':str(CALENDAR),'sourceUrl':calendar['source'],'sourceSnapshot':'2026-10-08','opening':'2026-09-01','reservationBoundary':'2026-12-21','boundaryDerivation':'Day before own published winter vacation begins Dec22, not an explicitly printed final class day.','midtermHeld':['2026-10-20','2026-10-26'],'finalHeld':['2026-12-15','2026-12-21'],'individualWeeklyDates':'Reservations from published regular weekday/HH:mm/room, not confirmed attendance; explicit source exam/holiday rows held.'},'wholeFreshnessGap':'No new wholeanonymouscatalogrecheck/latestclosures; official source is Oct8 frozen current2026-2. Changes after snapshot and actualindividualattendance remain unconfirmed.'}
(OUT/'semantic-native-operating-audit.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in receipt.items() if k not in ['proofs','inputSHA256']})
