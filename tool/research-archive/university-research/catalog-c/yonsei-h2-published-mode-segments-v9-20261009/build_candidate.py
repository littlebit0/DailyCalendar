import pathlib,json,re,datetime as dt,copy,collections,hashlib
from parse_mirae_education_groups import parse,CLOCK
p=pathlib.Path(__file__).parent;load=lambda f:json.loads(f.read_text());base=load(p/'baseline-yonsei-mirae-2026-2.json');candidate=copy.deepcopy(base)
assert len(base['courses'])==1218 and sum(bool(c['schedules']) for c in base['courses'])==911 and sum(len(c['schedules']) for c in base['courses'])==33308
clock=load(p/'current-native-clock-proof-v1.json')[1];clocks={r['period']:(r['startMinute'],r['endMinute']) for r in clock['nativeClockRows']};assert CLOCK==clocks
native=load(pathlib.Path('work/university-research/catalog-d/yonsei-2026-2-public-all.json'));ng=collections.defaultdict(list)
for r in native['records']:ng[(r['sysinstDivCd'],r['subjtnbCorsePrcts'])].append(r)
dates=[];d=dt.date(2026,9,1)
while d<=dt.date(2026,12,7):
 if d.isoformat() not in {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'} and not dt.date(2026,10,20)<=d<=dt.date(2026,10,26):dates.append(d)
 d+=dt.timedelta(days=1)
video={'동영상(미래,중복수강가능)':True,'동영상(중복수강불가)':False};proof=[];held=[];literal75=[]
for c in candidate['courses']:
 e=c['sourceEducation'][0]
 if c['schedules'] or '온라인·혼합' not in c['remarks']:continue
 assert e['sysinstDivCd']=='H2' and e['campsDivNm']=='미래';times=c['sourceSchedule'].split('/');rooms=c['sourceClassroom'].split('/');notes=e['atntnMattrDesc'] or ''
 kind=(e['subjtClNm'] or '').strip()
 if kind not in ['블랜디드(동영상)','블랜디드(실시간+동영상)','비대면(실시간+동영상)'] or len(times)!=len(rooms) or len(times)<2:
  held.append({'sourceId':c['sourceId'],'reason':'Unpublished/video-only mode or native slash count not corresponding'});continue
 if c['courseCode'].startswith('UCR') or c['courseCode']=='YHE1102' or any(w in c['courseName'] for w in ['현장실습','인턴','개별연구','독립연구','사회봉사','연구지도','연구프로젝트']):
  held.append({'sourceId':c['sourceId'],'reason':'RC or explicit individual/field operation remains unconfirmed'});continue
 if any(w in notes for w in ['집중','격주','블록','실제수업시간','실제 수업시간','별도','현장','대면수업주차','주차별','주별','분반별','추후','수업계획서','사전협의']) or re.search(r'수업.{0,5}변경|시간.{0,5}변경',notes):
  held.append({'sourceId':c['sourceId'],'reason':'Exact/unreviewed individual teaching condition'});continue
 segments=[];slots=[]
 for i,(t,r) in enumerate(zip(times,rooms)):
  g={'index':i,'nativeTime':t,'nativeRoom':r,'nativeClassMode':e['subjtClNm'],'nativePracticumSection':c['nativePracticumSection']}
  if r in video:g.update({'operation':'recordedVideoHeld','overlapPermitted':video[r],'timedReservationsGenerated':False});segments.append(g);continue
  try:parsed=parse(t,r)
  except ValueError as ex:g.update({'operation':'unconfirmedHeld','reason':str(ex),'timedReservationsGenerated':False});segments.append(g);continue
  mode='liveOnline' if r=='실시간온라인(미래)' else 'inPerson'
  gs=[{'weekday':s['weekday'],'sourcePeriod':s['nativePeriod'],'startMinute':s['startMinute'],'endMinute':s['endMinute'],'classroom':s['classroom'],'sourceGroupIndex':i,'sourceGroupKind':s['nativeGroupKind'],'deliveryMode':mode} for s in parsed]
  g.update({'operation':mode,'nativeSlots':gs,'timedReservationsGenerated':True});slots+=gs;segments.append(g)
 if not slots:held.append({'sourceId':c['sourceId'],'reason':'No complete own0–10 known physical/live group','segments':segments});continue
 if '75분' in notes:
  m=re.search(r'75분 수업\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)',notes);active=[g for g in segments if g['timedReservationsGenerated']]
  if not m or len(active)!=1 or len({s['weekday'] for s in slots})!=1 or len({s['classroom'] for s in slots})!=1:
   held.append({'sourceId':c['sourceId'],'reason':'Explicit75HH ambiguous physical group or day','segments':segments});continue
  start=int(m[1])*60+int(m[2]);end=int(m[3])*60+int(m[4]);assert end-start==75 and min(s['startMinute'] for s in slots)==start
  assert c['sourceId'] in ['yonsei/H2/2026-2/MGT2007-03-00','yonsei/H2/2026-2/MGT3013-01-00']
  periods=[s['sourcePeriod'] for s in slots];assert periods==([3,4] if c['courseCode']=='MGT2007' else [8,9])
  s0=slots[0];slots=[{'weekday':s0['weekday'],'sourcePeriods':periods,'startMinute':start,'endMinute':end,'classroom':s0['classroom'],'sourceGroupIndex':s0['sourceGroupIndex'],'sourceGroupKind':'lecture','deliveryMode':'inPerson','explicitSourceHH':m[0]}]
  active[0]['nativeSlots']=slots;active[0]['explicit75SourceHH']=m[0];active[0]['general50MinuteClockApplied']=False
  literal75.append({'sourceId':c['sourceId'],'sourceNotesLiteral':notes,'weekday':slots[0]['weekday'],'sourceGroupIndex':s0['sourceGroupIndex'],'nativeTime':times[s0['sourceGroupIndex']],'nativeRoom':rooms[s0['sourceGroupIndex']],'nativePeriods':periods,'actualStartMinute':start,'actualEndMinute':end,'uniquePhysicalGroup':True,'videoGroupNotUsedForClock':True})
 before=copy.deepcopy(c);ns=ng[('H2',e['subjtnbCorsePrcts'])]
 assert ns and e['lessnSessnDivNm']=='학기' and e['rmvlcYn']=='0'
 for n in ns:
  for k in ['lctreTimeNm','lecrmNm','subjtClNm','lessnSessnDivNm','cgprfNm','rmvlcYn','atntnMattrDesc']:assert n[k]==e[k]
 plans=[dict(s,date=d.isoformat()) for d in dates for s in slots if d.isoweekday()==s['weekday']];assert plans
 c['schedules']=plans;c['scheduleStatus']='scheduled';c['partialCoverage']=True;c['publishedModeSegments']=segments;c['priorHeldResearchRemarks']=before['remarks'];c['priorHeldDepartmentRemarks']=before['departmentRemarks']
 heldText=[]
 for g in segments:
  if g['operation']=='recordedVideoHeld':detail='영상, '+('다른 수업과 시간 중복 수강 가능' if g['overlapPermitted'] else '다른 수업과 시간 중복 수강 불가')+'; 시각 출석 예약 없음'
  elif g['operation']=='unconfirmedHeld':detail='자체 교시 시각/표기 미확정; 예약 보류'
  else:continue
  heldText.append(g['nativeTime']+' · '+g['nativeRoom']+' ['+detail+']')
 note='\n부분 시간표: 본교 미래캠퍼스 H2 2026-2 편람의 시간/강의실 구분에 따른 명확한 대면 구간만 예약합니다. 영상 구간과 미확정 구간의 원문·시간·중복 여부를 보존하며 출석 일정으로 생성하지 않습니다. 원문에 명시된 선학습·이수 제한·실습분반을 유지하고, 시험과 개별 변경은 별도 확인이 필요합니다.\n영상·미확정 원문 구간: '+' / '.join(heldText)
 if '75분' in notes:note+='\n이 강좌만 원문75분 명시시각을 적용하며 일반50분 교시표에 전파하지 않습니다.'
 c['remarks']=before['remarks'].split('\n일정 보류:')[0]+note;c['departmentRemarks']={k:v.split('\n일정 보류:')[0]+note for k,v in before['departmentRemarks'].items()}
 c['publishedModeProof']={'sourceURL':'https://mirae.yonsei.ac.kr/bbs/wj/104/1013900/download.do','sourcePhysicalPage':7,'sourcePrintedPage':5,'sourcePDFSHA256':'9541d000d7f22b451c955aefc103f30b6ad5d86f2bbad5bd36e12ee541e59c26','H1GuideBorrowed':False,'sourceMiraeParenthesisLegendOnly':True,'videoCalendarAppointmentsGenerated':0}
 for k in before:
  if k not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[k]==before[k]
 proof.append({'sourceId':c['sourceId'],'nativeCombinedReference':e['subjtnbCorsePrcts'],'nativeSourceWholeEqual':True,'originalNativeClosureModeNotesMatch':True,'segments':segments,'slots':slots,'plans':len(plans),'actual75Explicit':bool('75분' in notes)})
assert len(proof)==83 and len(literal75)==2
candidate.update({'researchOnly':True,'completionClaim':False,'wholeOperatingVerified':False});out=p/'yonsei-mirae-2026-2.mode-segments-v9.json';out.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
report={'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'partialCoverage':True,'priorMetadata':1218,'priorScheduled':911,'priorMeetings':33308,'newPartialCourses':83,'newTimedMeetings':sum(c['plans'] for c in proof),'newGeneral50MinuteCourses':81,'newExplicit75MinuteCourses':2,'newVideoAppointments':0,'byCourse':proof,'heldModeReview':held,'exactOwn75Rows':literal75,'candidateSHA256':hashlib.sha256(out.read_bytes()).hexdigest()}
(p/'native83-scoped-mode-proof.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('new83',report['newTimedMeetings'],'total',sum(bool(c['schedules']) for c in candidate['courses']),sum(len(c['schedules']) for c in candidate['courses']))
