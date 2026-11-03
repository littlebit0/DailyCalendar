# -*- coding: utf-8 -*-
import pathlib,shutil,json,hashlib,collections,datetime as dt
S=pathlib.Path('work/university-research/baekseok-cnu-current-whole-bulk-v4-20261010');D=S.with_name('baekseok-cnu-current-whole-bulk-v5-20261010');D.mkdir(exist_ok=False)
for f in S.iterdir():
 if f.is_file()and f.name!='SHA256SUMS.json':shutil.copyfile(f,D/f.name)
def load(n):return json.loads((D/n).read_text())
def dump(n,x):(D/n).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
p=load('proof.json');queue=load('queue.json');archive=load('previous-full-remarks-archive.json');status=load('previous-generated-status-archive.json');held={};fixed={};keep=[]
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
for q in p['newCourses']:
 before=q['originalWholeObject'];fields=before['sourceEducation']['originalEducationFields'];parts=fields['PNT_TMCNT'].split('/');expected=(float(parts[1])+float(parts[2]))*60;groups=collections.defaultdict(list)
 for b in q['literalSlots']:groups[b['weekday'],b['startMinute'],b['endMinute']].append(b)
 total=sum(end-start for day,start,end in groups)
 if total>=expected*2:
  held[q['sourceId']]=before;queue.append({'school':'cnu','sourceId':q['sourceId'],'courseCode':before['courseCode'],'section':before['section'],'reason':['published aggregate weekly clock greatly exceeds native theory/practical hours; individual concentrated/medical period allocation not confirmed'],'sourceSchedule':before['sourceSchedule'],'sourceEvidence':q['wholeSourceEvidence']});archive.pop(q['sourceId']);status.pop(q['sourceId']);continue
 slots=[]
 for key,bs in groups.items():slots.append({'weekday':key[0],'startMinute':key[1],'endMinute':key[2],'classroom':bs[0]['classroom']if len({b['classroom']for b in bs})==1 else ''})
 if slots!=q['literalSlots']:
  q['previousOriginalLiteralMultipleRoomSlots']=q['literalSlots'];q['literalSlots']=slots;q['sameOwnClockMultipleRoomAllocationUnconfirmed']=True;fixed[q['sourceId']]=slots
 keep.append(q)
p['newCourses']=keep
for ds in p['datasets']:
 data=load(ds['candidate']);nc=nm=0
 for i,c in enumerate(data['courses']):
  sid=c['sourceId']
  if sid in held:data['courses'][i]=held[sid];continue
  if sid in fixed:
   c['schedules']=[]
   for b in fixed[sid]:
    d=dt.date(2026,9,1)
    while d<=dt.date(2026,12,18):
     if d.isoweekday()==b['weekday']and str(d)not in closed:c['schedules'].append({**b,'date':str(d)})
     d+=dt.timedelta(days=1)
   c['bulkCurrentReservationReview']['multipleExactClockRoomRowsCollapsedWithBlankRoom']=True
  if sid in {q['sourceId']for q in keep}:
   q=next(q for q in keep if q['sourceId']==sid);q['meetings']=len(c['schedules']);nc+=1;nm+=len(c['schedules'])
 ds.update(newScheduled=nc,newMeetings=nm,candidateScheduled=ds['baselineScheduled']+nc,candidateMeetings=ds['baselineMeetings']+nm);dump(ds['candidate'],data)
summary={s:{'whole':sum(x['whole']for x in p['datasets']if x['school']==s),'processedHeld':sum(x['whole']-x['baselineScheduled']for x in p['datasets']if x['school']==s),'newScheduled':sum(x['newScheduled']for x in p['datasets']if x['school']==s),'newMeetings':sum(x['newMeetings']for x in p['datasets']if x['school']==s),'queue':sum(x['school']==s for x in queue),'reasonCounts':dict(collections.Counter(r for q in queue if q['school']==s for r in q['reason']))}for s in ['baekseok','cnu']};dump('proof.json',p);dump('summary.json',summary);dump('queue.json',queue);dump('previous-full-remarks-archive.json',archive);dump('previous-generated-status-archive.json',status);dump('narrow-pre-freeze-medical-aggregate-and-room-refinement-receipt.json',{'heldCourseIds':sorted(held),'sameExactClockRoomCollapseIds':sorted(fixed),'noNewSourceCollected':True,'priorV4BytesUnchanged':True,'regular150minuteCapstoneNative180minuteHoursNotAssumedConflict':'1314-4001-00','sourceMedicalTitleAloneNotUsed':True})
fixture=(D/'bu_cnu_combined_fixture_test.dart.txt').read_text().replace('bulk-v4-20261010','bulk-v5-20261010').replace('hasLength(192)','hasLength(179)').replace('hasLength(4402)','hasLength(4415)').replace('expect(added,6427)','expect(added,NEW_DATES)').replace('hasLength(2057)','hasLength(2044)')
fixture=fixture.replace("expect(slots,p['literalSlots']);", "final groups=<String,List<Map<String,dynamic>>>{};for(final b in slots){final key='${b['weekday']}/${b['startMinute']}/${b['endMinute']}';groups.putIfAbsent(key,()=>[]).add(b);}final collapsed=<Map<String,dynamic>>[];for(final bs in groups.values){collapsed.add({...bs.first,'classroom':bs.map((b)=>b['classroom']).toSet().length==1?bs.first['classroom']:''});}expect(collapsed,p['literalSlots']);")
fixture=fixture.replace('for(final b in slots){for(var d=DateTime','for(final b in collapsed){for(var d=DateTime');nd=sum(x['newMeetings']for x in p['datasets']);fixture=fixture.replace('NEW_DATES',str(nd));(D/'bu_cnu_combined_fixture_test.dart.txt').write_text(fixture)
(D/'HANDOFF.md').write_text(f'''# 백석·충남 현재 전체 미예약 bulk 최신v5\n\n전체6459 객체/미예약4594행 구조화 처리, 백석0신규/2549큐, 충남179신규/{nd}회/1866큐입니다. 기존1865강좌/45754회 전체 보존. 합계2044예약강좌/{45754+nd}회. SDK/제품/AGENT_MEMORY/새네트워크0. 실제출석·전체지원완료·불가능 주장0.\n\n백석 일반 학부 native교시 있으나 ownabsoluteHH 캐시근거 미확인,계약학과20시각은 일반2549에 전파하지 않았습니다. 현재22예약은 그대로입니다.\n\n충남 전체 현재개별 header/weeks·원래수강편람fields/HH를 일괄분류,실제 원격혼합·집중·개인배정·field주차·폐강·시각변경은 큐유지. 주제/교재/일반발표/실험 자체를 개인운영으로 취급하지 않았습니다. 다만 medical/임상 aggregate timetable이 native시수의2배 이상인13행은 개별운영기간 미확인으로 추가보류하여 전체학기매주 추정하지 않았습니다. 150분공시/3학시 캡스톤은 단순50분교시 가능성이 있고 printedHH명확하므로 불일치로 단정하지 않았습니다.\n\n1291-2014-00/01,1764-2002-00 세행은 정확같은own요일/HH에 두원문실이표시되어 같은시각중복만collapse하고classroom빈값입니다. 다른강좌 장소차용0,학교원문 전체 장소/HH/분반은 preservedsourceEducation에서정확보존합니다. nursing의 aggregate배정표는 이규칙으로해소하지않고13queue에유지했습니다. 캠퍼스unknown불변.\n\n학교자체9/1–12/18,휴업일및12/8–11보충기간 제외 공개정규예약입니다. 실제 최신운영완료·새시험/보강 추정0,사용자3모드 유지. generated sourceEducation3상태필드/정확warning만 외부 전체원본 archive와함께정정합니다. 학교 originalEducationFields 및 actualDisplayedClocks는 불변입니다.\n\n통합fixture하나 준비/미실행. 원문 HH독립parse,exactsameclock roomcollapse,모든학교필드/원문비고/전체객체/3모드Drive검증. v1/v2 parserdraft/v3경고전/v4 aggregate refinement전본 대신 채택v5. 기존모든입력 동결불변. parser/finalize 재실행금지.\n''')
(D/'narrow-refine-and-freeze.py').write_bytes(pathlib.Path(__file__).read_bytes());files={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}for f in sorted(D.iterdir())if f.is_file()and f.name!='SHA256SUMS.json'};dump('SHA256SUMS.json',{'files':files});print(len(files),hashlib.sha256((D/'SHA256SUMS.json').read_bytes()).hexdigest());print(summary)
