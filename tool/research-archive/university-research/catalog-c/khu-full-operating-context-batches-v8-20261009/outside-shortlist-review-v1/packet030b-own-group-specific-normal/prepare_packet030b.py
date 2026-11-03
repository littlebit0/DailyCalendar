# coding: utf-8
import pathlib,json,hashlib,datetime as dt,re,copy
b=pathlib.Path('work/university-research/catalog-c/khu-full-operating-context-batches-v8-20261009/outside-shortlist-review-v1');p=b/'packet030b-own-group-specific-normal';assert p.exists() and not list(p.iterdir());xs=json.load(open(b/'packet030-reviewed30/packet030-30-full-source-prepared.json'))
# Ordinal, own professor plan index, native group index, literal own normal week and date.
cases=[(854,0,1,8,'2026-10-20',2,780,890,'스B245'),(854,1,0,15,'2026-12-08',2,540,705,'스B112'),(855,0,0,7,'2026-10-13',2,630,795,'스B114(계단)'),(855,1,1,8,'2026-10-23',5,540,650,'스B245'),(856,1,0,7,'2026-10-13',2,630,795,'스B114(계단)'),(856,0,1,8,'2026-10-23',5,660,770,'스B245'),(857,1,0,7,'2026-10-13',2,630,795,'스B114(계단)'),(857,0,1,8,'2026-10-21',3,900,1010,'스B245')]
pattern=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)');proof=[];adds={};shas={}
for n,pi,gi,w,date,wd,st,en,room in cases:
 x=xs[n-831];c=x['originalWholeObject'];z=x['plans'][pi];plan=z['originalWholeEducationPlan'];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd'] and plan['campus']=='서울'
 m=list(pattern.finditer(c['sourceSchedule']))[gi];native=['월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()];assert native==[wd,st,en,room]
 sec={z['section']:z['rows']for z in plan['educationalSections']};rows=sec['주별강의내용'];r=next(r for r in rows if r[0]==str(w)+'주');a,bb,zz,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());day=dt.date.fromisoformat(date);assert dt.date(2026,a,bb)<=day<=dt.date(2026,zz,d) and day.isoweekday()==wd
 assert not any(t in r[2] for t in ['중간','기말','휴강','보충실험'])
 basic=next(r[1]for r in sec['기본정보']if r[0]=='강의시간강의실');norm=re.sub(r'\s','',basic);assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5]in norm and re.sub(r'\s','',room)in norm
 assert date not in {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
 op=str(sec['수업운영방식']);types=str(sec['수업유형 및 방법']);assert ('대면 실험 수업'in op or '대면 실험수업으로 운영'in op)or('강의실 활동'in op and '대면수업'in op)or('강의실'in r[3] and '이론에 해당'in types)
 meeting={'date':date,'weekday':wd,'startMinute':st,'endMinute':en,'classroom':room};adds.setdefault(c['sourceId'],[]).append(meeting)
 shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest();proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholeNativeCourseObject':c,'wholeEducationPlan':plan,'ownProfessorPlanIndex':pi,'nativeGroupIndex':gi,'literalNativeClock':c['sourceSchedule'],'literalWholeSelectedWeekRow':r,'literalExpectedMeeting':meeting,'wholeOwnOperation':sec['수업운영방식'],'wholeOwnTeachingType':sec['수업유형 및 방법'],'ownExamNormalException':w==8,'noOtherGroupOperatingPropagation':True})
for ca in ['seoul','global']:
 old=json.load(open(b/'packet030-reviewed30'/f'khu-{ca}-2026-2.packet030-physical-groups-prepared.json'));(p/f'packet030b-prior-{ca}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId']not in adds:continue
  assert len(adds[c['sourceId']])==2
  for m in adds[c['sourceId']]:assert m not in c['schedules'];assert not any(t['date']==m['date'] and t['startMinute']==m['startMinute']for t in c['schedules'])
  c['schedules']+=adds[c['sourceId']]
 oldm={c['sourceId']:c for c in old['courses']};assert all(c==oldm[c['sourceId']]for c in new['courses']if c['sourceId']not in adds)
 for c in new['courses']:
  if c['sourceId']in adds:assert {k:v for k,v in c.items()if k!='schedules'}=={k:v for k,v in oldm[c['sourceId']].items()if k!='schedules'}
 (p/f'khu-{ca}-2026-2.packet030b-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
pr={'completionClaim':False,'SDKExecutions':0,'newCourses':0,'alreadyPreparedCoursesExtended':4,'newMeetings':8,'baselineScheduled':2843,'baselineMeetings':53320,'candidateScheduled':2843,'candidateMeetings':53328,'proofs':proof,'originalPlanSHA256':shas};(p/'packet030b-independent-proof.json').write_text(json.dumps(pr,ensure_ascii=False,indent=2)+'\n');(p/'packet030b-independent-literal-additions.json').write_text(json.dumps(adds,ensure_ascii=False,indent=2)+'\n');(p/'own-current-calendar.json').write_bytes(pathlib.Path('work/university-research/catalog-u/khu-current-calendar-period-proof-20261008.json').read_bytes())
