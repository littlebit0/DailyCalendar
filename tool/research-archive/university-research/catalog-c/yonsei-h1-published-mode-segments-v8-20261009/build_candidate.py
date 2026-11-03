import pathlib,json,re,datetime as dt,copy,collections,hashlib
p=pathlib.Path(__file__).parent;load=lambda f:json.loads(f.read_text())
clock=load(p/'current-native-clock-proof-v1.json')[0];clocks={r['period']:(r['startMinute'],r['endMinute']) for r in clock['nativeClockRows']};assert set(clocks)==set(range(11))
guard=['75분','집중','격주','블록','실제수업시간','실제 수업시간','별도','현장','변경','대면수업주차','주차별','주별','분반별','추후','수업계획서','사전협의']
dates=[];day=dt.date(2026,9,1)
while day<=dt.date(2026,12,7):
 if day.isoformat() not in {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'} and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26):dates.append(day)
 day+=dt.timedelta(days=1)
raw=load(pathlib.Path('work/university-research/catalog-d/yonsei-2026-2-public-all.json'));nativegroups=collections.defaultdict(list)
for r in raw['records']:nativegroups[(r['sysinstDivCd'],r['subjtnbCorsePrcts'])].append(r)
proof=[];heldreview=[];man=[]
for f in sorted(p.glob('baseline-yonsei-*-2026-2.json')):
 d=load(f);candidate=copy.deepcopy(d);startProofCount=len(proof)
 for c in candidate['courses']:
  e=c['sourceEducation'][0]
  if c['schedules'] or e['sysinstDivCd']!='H1' or '온라인·혼합' not in c['remarks']:continue
  mode=(e['subjtClNm'] or '').strip();times=c['sourceSchedule'].split('/');rooms=c['sourceClassroom'].split('/');notes=e['atntnMattrDesc'] or ''
  if c['courseCode'].startswith('UCR') or 'Residential' in (e['subjtEngNm'] or '') or any(w in c['courseName'] for w in ['현장실습','인턴','개별연구','독립연구','사회봉사','연구지도','연구프로젝트']):
   heldreview.append({'sourceId':c['sourceId'],'reason':'RC or explicit individual/field operation source remains held'});continue
  if mode not in ['블랜디드(동영상)','블랜디드(실시간+동영상)','비대면(실시간+동영상)'] or len(times)!=len(rooms) or len(times)<2:
   heldreview.append({'sourceId':c['sourceId'],'reason':'Course mode unsupported or explicit index pairing absent'});continue
  segments=[];slots=[]
  for index,(t,r) in enumerate(zip(times,rooms)):
   group={'index':index,'nativeTime':t,'nativeRoom':r,'sourceClassMode':e['subjtClNm'],'sourcePracticumSection':c['nativePracticumSection']}
   if r in ['동영상콘텐츠','동영상(중복수강불가)']:
    group.update({'operation':'recordedVideoHeld','overlapPermitted':r=='동영상콘텐츠','timedReservationsGenerated':False});segments.append(group);continue
   if '(' in t or ')' in t or '(' in r or ')' in r or not r or any(w in r for w in ['미정','미배정','동영상','콘텐츠']):
    group.update({'operation':'unconfirmedHeld','reason':'H1 parenthesis/room semantics or room missing','timedReservationsGenerated':False});segments.append(group);continue
   matches=list(re.finditer(r'([월화수목금토])(\d+(?:,\d+)*)',t))
   if ','.join(m[0] for m in matches)!=t or not matches or not all(int(v) in clocks for m in matches for v in m[2].split(',')):
    group.update({'operation':'unconfirmedHeld','reason':'Native syntax or own0–10 period clock unsupported','timedReservationsGenerated':False});segments.append(group);continue
   group.update({'operation':'liveOnline' if r=='실시간온라인' else 'inPerson','timedReservationsGenerated':True,'nativeSlots':[]})
   for m in matches:
    for period in map(int,m[2].split(',')):
     slot={'sourceGroupIndex':index,'sourcePeriod':period,'weekday':'월화수목금토'.index(m[1])+1,'startMinute':clocks[period][0],'endMinute':clocks[period][1],'classroom':r,'deliveryMode':group['operation']};group['nativeSlots'].append(slot);slots.append(slot)
   segments.append(group)
  if not slots or any(s in notes for s in guard):
   heldreview.append({'sourceId':c['sourceId'],'reason':'No exact physical/live clock group or explicit/unreviewed individual operation note','segments':segments});continue
  before=copy.deepcopy(c);assert e['lessnSessnDivNm']=='학기' and e['rmvlcYn']=='0' and c['campus'] in ['sinchon','international']
  ns=nativegroups[('H1',e['subjtnbCorsePrcts'])];assert all(n['rmvlcYn']=='0' and n['lctreTimeNm']==e['lctreTimeNm'] and n['lecrmNm']==e['lecrmNm'] and n['subjtClNm']==e['subjtClNm'] and n['lessnSessnDivNm']==e['lessnSessnDivNm'] and n['cgprfNm']==e['cgprfNm'] for n in ns)
  plans=[dict(s,date=date.isoformat()) for date in dates for s in slots if date.isoweekday()==s['weekday']];assert plans
  c['schedules']=plans;c['scheduleStatus']='scheduled';c['partialCoverage']=True;c['publishedModeSegments']=segments
  c['priorHeldResearchRemarks']=before['remarks'];c['priorHeldDepartmentRemarks']=before['departmentRemarks']
  note='\n부분 시간표: 본교 H1 2026-2 편람의 시간/강의실 구분에 따른 명확한 대면·실시간 그룹만 예약합니다. 영상 그룹 원문/시간/중복 가능 여부와 미확정 그룹은 보존하되 출석 일정으로 생성하지 않습니다. 원문 분반·실습분반 및 그룹 순서를 유지하며, 시험/개별 변경·영상 완료 일정은 별도 확인이 필요합니다.'
  heldDescriptions=[]
  for g in segments:
   if g['operation']=='recordedVideoHeld':
    detail='영상, '+('다른 수업과 시간 중복 수강 가능' if g['overlapPermitted'] else '다른 수업과 시간 중복 수강 불가')+'; 시각 출석 예약 없음'
   elif g['operation']=='unconfirmedHeld':detail='표기 의미/시각 미확정; 예약 보류'
   else:continue
   heldDescriptions.append(g['nativeTime']+' · '+g['nativeRoom']+' ['+detail+']')
  note+='\n영상·미확정 원문 구간: '+' / '.join(heldDescriptions)
  c['remarks']=before['remarks'].split('\n일정 보류:')[0]+note
  c['departmentRemarks']={k:v.split('\n일정 보류:')[0]+note for k,v in before['departmentRemarks'].items()}
  c['publishedModeProof']={'scope':'H1 own current2026-2 published native time/room groups','sourceURL':'https://www.yonsei.ac.kr/bbs/sc/58/1013898/download.do','sourcePhysicalPage':7,'sourcePrintedPage':5,'sourcePDFSHA256':'5d46c008e7b4a3f690a3f0a3d1a05a30d2c076d1b383fd55b2485be62ec16822','videoCalendarAppointmentsGenerated':0,'H2LegendBorrowed':False}
  for k in before:
   if k not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[k]==before[k],k
  proof.append({'sourceId':c['sourceId'],'campus':c['campus'],'nativeCombinedReference':e['subjtnbCorsePrcts'],'nativeTime':e['lctreTimeNm'],'nativeRoom':e['lecrmNm'],'nativeMode':e['subjtClNm'],'nativeClosed':e['rmvlcYn'],'sourceEducationWholeEqual':True,'priorSourcedWholeFieldsPreserved':True,'nativeSemester':e['lessnSessnDivNm'],'segments':segments,'knownSlots':slots,'plans':len(plans),'sourceIdentityOriginalRawMatched':True})
 candidate.update({'researchOnly':True,'completionClaim':False,'wholeOperatingVerified':False})
 out=p/(f.name.replace('baseline-','').replace('.json','.mode-segments-v8.json'));out.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n') if len(proof)>startProofCount else out.write_bytes(f.read_bytes());man.append({'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'metadata':len(candidate['courses']),'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'meetings':sum(len(c['schedules']) for c in candidate['courses'])})
assert len(proof)==359
summary={'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'partialCoverage':True,'priorCourses':4710,'priorScheduled':2722,'priorMeetings':97066,'newPartialCourses':359,'newTimedMeetings':sum(x['plans'] for x in proof),'newVideoTimedMeetings':0,'manifest':man,'byCourse':proof,'heldModeReview':heldreview,'modeCounts':dict(collections.Counter(x['nativeMode'] for x in proof)),'ownDateRange':{'start':'2026-09-01','regularEnd':'2026-12-07','actualAttendanceClaim':False}}
(p/'native359-mode-segment-proof.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');print('new',359,summary['newTimedMeetings'],'total',[(x['file'],x['scheduled'],x['meetings']) for x in man])
