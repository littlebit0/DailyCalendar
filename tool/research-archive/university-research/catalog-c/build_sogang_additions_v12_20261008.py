"""Twenty native offerings reviewed; current printed educational dates only."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent;O=R/'sogang-additions-v12-20261008';B=R/'sogang-additions-v11-20261008/sogang-unknown-2026-2.ninety-five-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[];held=[]
configs=[
 ('CHU4002-01',25,['2026-10-05','2026-10-21','2026-12-16'],'전체학년1~4. source중간10/21 vs public10/26충돌 held; 실제9주10/28한날짜만,10/26추정안함. 10/5공휴일·12/16기말clock미확인 held. source자유선택교과 원문 보존, broad분류미추정.'),
 ('GKS3001-01',26,['2026-09-10','2026-09-24','2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'source10/20중간 vs current10/22원문NoClass충돌: 두시험일 held.9/10/24·12/17NoClass와12/15finalclock미확인held. 정규강의·조별활동·발표만. 그룹역할순환·참여·자료수업제공·전자기기수업활동조건 보존.'),
 ('GKS3009-01',26,['2026-09-10','2026-09-24','2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'source10/20중간 vs current10/22(sourceNoClass)충돌 held.9/10/24·12/17NoClass 및12/15finalclock미확인held. 정규강의·조별사례분석·발표만; 그룹역할순환·교실전자기기·수업자료공급조건 보존.'),
 ('HFS2002-04',27,['2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'전학년. source휴일후9/29·10/1/6/8/13/15로 실제주제별시작일변화보존, 학사표준주로변환안함. 중간/기말 주의두날짜 실제시험배정미확인 held. 토론·영상시청은 수업활동이며VOD모드로추정없음.'),
 ('HFS2003-02',26,['2026-10-20','2026-10-26','2026-12-15','2026-12-21'],'2학년. source수업은대면강의로진행 명시 실제inPerson보존.15주에는12/08한날짜만 원문좌표에서확인,12/10반복추가안함. 중간·기말평가기간 실제시험일배정미확인 held. 강의자료사전읽기·보고서2회·모둠토론·변경조건 보존.'),
 ('HFS2003-04',27,['2026-09-24','2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'전학년. 표의12/1과12/3은 원본좌표별칸으로대조;10/27,29는 같은날짜열의명시공통월표기 실제좌표로대조. 중간/기말주 두날짜 배정미확인held. 교실영상자료는VOD모드추정안함. 팀토론·개인성찰·토론보고서조건 보존.'),
 ('KOR3414-01',24,['2026-09-18','2026-09-25','2026-10-09','2026-10-21','2026-10-23','2026-11-20','2026-12-16','2026-12-18'],'전학년권장2~4, 증원·추가등록불허. 9/18source서강문화제휴강·추석9/25·한글날10/9·11/20교내휴강일 제외. 8주사이버캠퍼스개별연구계획피드백 모드·시각미확인,16주소논문제출 출석미확인 held. 9~15주실제날짜개별발표·토론·교수현장피드백만.'),
 ('MAS2007-01',26,['2026-09-03','2026-10-05','2026-10-21','2026-10-26','2026-12-16','2026-12-21'],'학부2/3/4.첫source9/3은목요일로 native월수와충돌 held,9/2로고치지않음.10/5holiday와중간/기말주시험실제배정미확인held. source사진·영화·이미지 역사강의 실제날짜보존.'),
 ('MAT3310-01',24,['2026-09-18','2026-09-25','2026-10-09','2026-10-23','2026-11-20','2026-12-18'],'2~4학년.9/18festival운영미확인/9/25추석/10/9한글날/11/20교내휴강 제외.중간source13:30~14:50 vs current14:45종료 충돌 held.12/18finalsource1:30~2:50시험시각은 실제AM/PM·public배정미확인held. 정규75분만 보존.'),
 ('MGT4104-01',27,['2026-10-05'],'선수MGT3001조직행동이론. 실제날짜일반·팀과제발표·개인발표만,10/5holiday제외. 8주EXAM1날짜미인쇄/current10/26시험source미확인 및16주내용미인쇄 held. 날짜없는시험을상시반복으로추정하지않음.'),
 ('MGT4601-01',27,['2026-10-05','2026-10-19','2026-10-21','2026-12-16','2026-12-21'],'source중간은10/19또는21후속배정 조건, current21만으로source모호성해제안함. 10/26은원문정규수업명시보존. final포스터전시/동료평가제출16·21 실제출석미확인held;10/5NoClass. 팀발표·사례토론·온라인퀴즈는수업모드와분리보존.'),
 ('MGT4615-01',25,['2026-10-05','2026-10-19','2026-10-21','2026-10-26','2026-10-28','2026-12-16','2026-12-21'],'actual창업캡스톤 강의·토론·발표 날짜만.10/28수업대신10월말Coex정주영창업대회 실제방문일시미배정 held.10/26teammeeting/startupfoundation Format공란·16주개별feedback16delivery/room미확인·21proposal/peer평가제출 held.중간19/21미확정,10/5NoClass. 실제일반lecture/PT그룹토론 및14일DemoDay발표보존.'),
 ('MGTG244-01',27,['2026-09-10','2026-09-24','2026-10-20','2026-10-26','2026-12-15','2026-12-21'],'학부3/4 및일반대학원석사 학석통합과목; 현재학부nativeMGTG244-01만분리. source대면강의/대면시험 및75분in-class에세이closedbook 명시inPerson보존.9/10개강미사/9/24휴강제외(원문설날표기그대로보존,실제추석date). mid공개10/22MA208·10:30~11:45와source현재midperiod/75분inclass일치만1회반영. final일시미배정 held.'),
 ('PSY3002-01',28,['2026-09-24','2026-10-22','2026-12-15','2026-12-17'],'선수/학년sourceHeader조건보존.정규27 및source/public10/20D202·15~16:15중간1. source9/24/10/22/12/17NoClass제외,12/15final실제clock미공개held. VideoClip은교실강의활동이며VOD모드로추정없음.15분지각/FA·조기퇴실·자료정직성조건 보존.'),
 ('PSY4034-01',26,['2026-09-22','2026-09-24','2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'Juniorstanding이상,sourceHeader추가선수/전공수강조건보존.4주추석전체NoClass22/24제외. current10/20exam vs source10/20NoClass/10/22TBA시험충돌 held, final15TBA/17NoClassheld. source교실TBA/current확정DB101사용. 일반강의·토론 실제날짜만, 온라인활동녹음금지를실제online운영근거로오해안함.'),
]
held_reasons={'COR1012-02':'current native02 vs original plan Course Number COR1012-01 section conflict; all dates held, no relabeling.','ECOG051-01':'current Fall2026 cross-listed actual course; generic offline/live Zoom/recorded attendance branches and exact per-date operating modality unallocated. Week ranges and two midterms need per-date operating confirmation before timed plans; office Zoom not class mode.','GIS1005-02':'native02 vs plan GIS1005-02 (1분반) native reference/section semantics conflict unresolved; source12:00~1:15 explicit PM unclear alone but current75min exact. Native examK303 vs regularK307 preserved separately.','HFU4003-01':'source Course Number HFS vs public HFU4003 differing reference; no identity correction guessed.','PHY1002-05':'public PDF Korean glyph extraction unreadable; course operation/student conditions need direct visual educational-page audit, held. Native code/time preserved, contacts removed.'}
for key,reason in held_reasons.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];assert s['currentBytesEqualPrior'];held.append({'offering':key,'reason':reason,'sourcePDFSHA256':s['fileSha256']})

def geometry_dates(key):
 fn=f'{key}.full-date-column-geometry.json' if key in {'HFS2003-02','HFS2003-04'} else f'{key}.date-geometry.json'
 g=json.loads((O/fn).read_text());dates=[];trace=[];previous=None
 for token in g['educationalDateTokens']:
  text=token['text'];matches=list(re.finditer(r'(\d{1,2})/(\d{1,2})(?:,\s*(\d{1,2})(?![/\d]))?',text));local=[]
  for m in matches:
   month=int(m[1]);day=int(m[2]);local.append(dt.date(2026,month,day))
   if m[3]:local.append(dt.date(2026,month,int(m[3])))
  if not local and re.fullmatch(r'\d{1,2}',text) and previous and previous['text'].endswith(',') and previous['page']==token['page'] and 0<token['top']-previous['top']<25:
   mo=int(re.search(r'(\d{1,2})/',previous['text'])[1]);local.append(dt.date(2026,mo,int(text)))
  for date in local:dates.append(date);trace.append({'date':date.isoformat(),'numericHeaderToken':token,'explicitSharedMonthToken':previous if '/' not in text else None,'geometryFile':fn})
  previous=token
 return sorted(set(dates)),trace
for key,expected,excluded,note in configs:
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];text=s['weeklyOperatingText'];c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and s['currentBytesEqualPrior'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1];assert end-start==75
 geom=[]
 if key in {'HFS2002-04','HFS2003-02','HFS2003-04','KOR3414-01'}:dates,geom=geometry_dates(key)
 else:dates=sorted(set(dt.date(2026,int(m),int(d)) for m,d in re.findall(r'(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])(?!\d)',text)))
 plans=[];holds=[]
 weekdays={3,5} if key in {'MAT3310-01','KOR3414-01'} else ({1,3} if key in {'CHU4002-01','MAS2007-01','MGT4104-01','MGT4601-01','MGT4615-01'} else {2,4})
 for date in dates:
  ds=date.isoformat()
  if ds in excluded:holds.append({'date':ds,'reason':note});continue
  assert date.isoweekday() in weekdays and dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  plan={'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  if key in {'HFS2003-02','MGTG244-01'}:plan['deliveryMode']='inPerson'
  plans.append(plan)
 if key=='MGTG244-01':
  assert row['exam']=='10.22(목)10:30~11:45[MA208]';assert '대면 강의' in s['sourceHeader']
  plans.append({'date':'2026-10-22','weekday':4,'startMinute':start,'endMinute':end,'classroom':room,'deliveryMode':'inPerson'})
 if key=='PSY3002-01':assert row['exam']=='10.20(화)15:00~16:15[D202]'
 assert len(plans)==expected,(key,len(plans),expected,[m['date'] for m in plans]);assert len({m['date'] for m in plans})==expected
 plans.sort(key=lambda m:m['date']);c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':expected,'attendanceConfirmed':False})
 if key=='CHU4002-01':c['sourceNativeClassification']='자유선택교과'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':expected,'nativeClock':row['meetingText'],'sourceDateGeometry':geom})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==15
count=sum(len(c['schedules']) for c in out['courses']);assert sum(bool(c['schedules']) for c in out['courses'])==110
f=O/'sogang-unknown-2026-2.one-hundred-ten-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'reviewedNativeOfferings':20,'previousScheduled':95,'previousPlans':2321,'addedScheduled':15,'addedPlans':count-2321,'scheduled':110,'plans':count,'changedOnly':changed,'proofs':proofs,'reviewedStillHeld':held,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('110/',count,'+15/',count-2321)
