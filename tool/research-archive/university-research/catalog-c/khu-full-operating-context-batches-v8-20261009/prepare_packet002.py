import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent; xs=json.load(open(P/'packet002-50-full-source-prepared.json'));W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
weeks={n:W[:] for n in [52,53,56,60,62,71,83,84,85,86,96,97,100]};weeks.update({54:[1,2,3,4,5,6,9,10,11,12,13,14],65:list(range(1,8)),66:list(range(1,8)),77:[1,2,3,4,5,6,7,9,10,11,12,13,14],87:W[:-1],94:W[:-1]});weeks[52].remove(6)
HH={52:[(5,540,705,'생510')],53:[(5,810,975,'생510')],54:[(2,810,975,'생510')],56:[(2,810,885,'생507'),(4,810,885,'생507')],60:[(2,540,615,'생507'),(4,540,615,'생507')],62:[(1,810,885,'생507'),(3,810,885,'생507')],65:[(2,840,915,'스361')],66:[(2,930,1005,'스361')],71:[(3,1080,1130,'스357')],77:[(3,600,650,'예1강의실')],83:[(4,600,710,'치B101')],84:[(4,600,710,'치B101')],85:[(4,600,710,'치B101')],86:[(3,960,1070,'약210')],87:[(1,900,1010,'약210')],94:[(1,780,890,'약410')],96:[(4,660,770,'약305')],97:[(4,630,740,'약210')],100:[(2,660,770,'약512')]}
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exceptDates={62:{'2026-09-07','2026-09-09','2026-10-28'}}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
proof=[]; selected={}; count=0; shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-51]; c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']));assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [( '월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert c['campus']=='seoul' and plan['campus']=='서울';assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  normal=re.sub(r'\s+','',next(r[1] for r in basic if r[0]=='강의시간강의실'))
  for m in native:assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[0]['educationalSections'] if s['section']=='주별강의내용'); own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w]; a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 meetings=[];independent=[]
 def permitted(day):return day.isoformat() not in closed|exceptDates.get(n,set()) and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21)
 for m in native:
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':m[6].strip()})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for wd,st,en,room in HH[n]:
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,room))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':'서울','literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'newDateCount':len(meetings),'originalResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 src=P/'packet001b-exact-research-note-correction'/f'khu-{campus}-2026-2.packet001b-prepared.json';old=json.load(open(src));(P/f'packet002-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격 예외는 생성하지 않습니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  if c['sourceId'] in {'khu/2026/2/seoul/KMS121600','khu/2026/2/seoul/KMS121601'}:note+=' 병리학실습2는 중간고사 이전 강의실 대면 이론만 포함하며 이후 개인 환자 실습은 예약하지 않습니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':2}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet002-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet002-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':1956,'baselineDates':36639,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':1956+len(selected),'totalDates':36639+count})
