import json,pathlib,hashlib,re,datetime,collections
base=pathlib.Path('work/university-research/catalog-r/suwon/full-query-partial-v2');base.mkdir(exist_ok=True)
rawbase=pathlib.Path('work/university-research/catalog-w/suwon')
files=['전체-p'+str(i) for i in range(1,109) if i!=5];files.insert(4,'전체-p5-revisit')
fields=['nativeSequence','organization','courseCode','title','section','additional','classification','credits','theory','practical','department','grade','time','mergedGroup','videoFlag','readingFlag','language','grading','professor','generalField','closureDate','closureReason']
rows={};refs=collections.defaultdict(list);hashes={}
for name in files:
 f=rawbase/(name+'-2026-2-public-education.json');raw=json.loads(f.read_text());hashes[str(f)]=hashlib.sha256(f.read_bytes()).hexdigest()
 rs=raw['rows'][:-1] if name in ['전체-p1','전체-p2','전체-p3','전체-p4'] else raw['rows']
 for i,r in enumerate(rs):
  if r[0] in rows:assert rows[r[0]]==r
  rows[r[0]]=r;refs[r[0]].append({'file':str(f),'completeRowIndex':i})
assert sorted(map(int,rows))==list(range(1,2597))
groups=collections.defaultdict(list)
for r in rows.values():groups[(r[2],r[4])].append(r)
clock=json.loads(pathlib.Path('work/university-research/catalog-r/suwon/public-guide-clock-followup-v2/educational-guide-clock.json').read_text())
calendar=json.loads(pathlib.Path('work/university-research/catalog-r/suwon/current-calendar-campus-v3/educational-calendar-campus.json').read_text())
cs=[]
for (code,sec),vs in groups.items():
 r=vs[0];holds=[]
 # department classification and eligibility variation retained; identity conflicts withheld
 for idx in [1,2,3,4,5,7,8,9,12,13,14,15,16,17,18,20,21]:
  if len({json.dumps(v[idx]) for v in vs})>1:holds.append('native identity/operation conflict field '+fields[idx])
 if any(v[20] or v[21] for v in vs):holds.append('native closure date/reason')
 if r[14] or r[15] or '이러닝' in r[3]+r[5]:holds.append('remote/video/reading operation unknown')
 if float(r[9] or 0)>0 or re.search('실험|실습|집중|프로젝트',r[3]+r[5]):holds.append('practical/intensive operating dates unknown')
 blocks=list(re.finditer(r'([^(),]+)\(([월화수목금])([1-8](?:,[1-8])*)\)',r[12]))
 if not blocks or ','.join(x.group(0) for x in blocks)!=r[12]:holds.append('unparsed/unknown period or room')
 if any([int(p) for p in x[3].split(',')]!=list(range(int(x[3].split(',')[0]),int(x[3].split(',')[-1])+1)) for x in blocks):holds.append('noncontiguous periods')
 schedules=[]
 if not holds:
  for x in blocks:
   a=int(x[3].split(',')[0]);z=int(x[3].split(',')[-1]);day='월화수목금'.index(x[2])+1
   for offset in range(20):
    dt=datetime.date(2026,9,1)+datetime.timedelta(days=offset)
    if dt.isoweekday()!=day:continue
    schedules.append({'weekday':day,'startMinute':570+60*(a-1),'endMinute':620+60*(z-1),'classroom':x[1],'date':dt.isoformat()})
 originals=[{'values':v,'provenances':refs[v[0]]} for v in sorted(vs,key=lambda v:int(v[0]))]
 departments=list(dict.fromkeys(v[10] for v in vs))
 c={'sourceId':'suwon/2026/2/'+code+'/'+sec,'campus':'unknown','academicYear':2026,'semester':'2','courseCode':code,'section':sec,'courseName':r[3],'professor':r[18],'classification':r[6],'credits':float(r[7]),'departments':departments,'departmentClassifications':{v[10]:v[6] for v in vs},'departmentCredits':{v[10]:float(v[7]) for v in vs},'sourceSchedule':r[12],'sourceClassroom':r[12],'remarks': '원문 추가정보: '+r[5]+' / 조회별 학과·학년·교과구분: '+'; '.join(v[10]+' / '+v[11]+' / '+v[6] for v in vs)+' / 합반번호: '+r[13]+' / 폐강: '+r[20]+' '+r[21]+' / 공개 초기3주 예약 부분범위 2026-09-01–09-20. 실제 출석·학기전체·시험없음 확인이 아닙니다. 학교 자체 개강/기말/보강은 확인했으나 중간시험·개별 운영 날짜는 미확인입니다. 교시1–8만 검증, 강의실 약칭에 따른 실제 캠퍼스 연결 미확인. 사용자 수업방식 선택 유지. '+('; '.join(holds) if holds else ''),'schedules':schedules,'scheduleStatus':'scheduled' if schedules else 'unrecognized','metadata':{'originalEducationalRecords':originals,'reservationHoldReasons':holds,'actualAttendanceConfirmed':False,'campusAssociationProven':False,'sourceCodePublished':True,'whole2596QueryAcquired':True,'snapshotCurrentWholeQueryRows':2596,'individualOperatingDaysVerified':False}}
 cs.append(c)
d={'schemaVersion':2,'universityId':'suwon','campus':'unknown','campusName':'원문 강의실 약칭 캠퍼스 연결 미확인','academicYear':2026,'semester':'2','publishedDate':'','sourceUrl':'https://info.suwon.ac.kr/websquare/websquare.jsp?w2xPath=/views/main.xml','researchOnly':True,'completionClaim':False,'courses':cs}
proof={'researchOnly':True,'completionClaim':False,'fields':fields,'sourceFilesSHA256':hashes,'nativeRows':list(sorted(rows.values(),key=lambda r:int(r[0]))),'clockEvidence':clock,'calendarEvidence':calendar,'reservationScope':{'start':'2026-09-01','end':'2026-09-20','meaning':'selected initial three week subset; no full term or no exam/actual attendance claim'},'incompleteLastRowsExcluded':['전체-p1','전체-p2','전체-p3','전체-p4']}
for name,obj in [('suwon-unknown-2026-2.early-planned.json',d),('educational-proof.json',proof)]: (base/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print(len(rows),len(cs),sum(bool(c['schedules']) for c in cs),sum(len(c['schedules']) for c in cs))
