import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet003-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={101:[(1,900,1010,'약B209')],104:[(5,780,890,'음259')],105:[(4,540,650,'음B101')],106:[(4,780,890,'음B101')],107:[(3,780,890,'앙상블실')],108:[(2,780,890,'음259')],109:[(1,780,890,'음B101')],114:[(1,720,885,'호403')],115:[(1,900,975,'호503'),(3,900,975,'호503')],116:[(1,990,1065,'호503'),(3,990,1065,'호503')],117:[(2,810,885,'호302'),(4,810,885,'호302')],118:[(2,720,795,'호502'),(4,720,795,'호502')],119:[(2,810,885,'호502'),(4,810,885,'호502')],122:[(2,900,1065,'호703')],123:[(4,540,705,'호603')],125:[(4,900,1065,'호701')],126:[(1,810,975,'호703')],129:[(1,720,795,'호402'),(3,720,795,'호402')],130:[(3,540,795,'호B102')],131:[(5,810,975,'호402')],132:[(1,810,1065,'호103')],133:[(3,1080,1245,'호406')],134:[(6,540,705,'호502')],136:[(1,1170,1305,'호402')],137:[(6,780,945,'호503')],139:[(1,810,885,'호301'),(3,810,885,'호301')],140:[(2,720,795,'호503'),(4,720,795,'호503')],141:[(2,810,885,'호503'),(4,810,885,'호503')],143:[(1,720,885,'호501')],144:[(5,810,975,'호403')],145:[(5,540,705,'호403')],146:[(1,540,615,'문305'),(3,540,615,'문305')],147:[(1,900,975,'문401'),(3,900,975,'문401')],148:[(1,720,795,'문401'),(3,720,795,'문401')],149:[(2,540,615,'문401'),(4,540,615,'문401')],150:[(2,630,705,'문403'),(4,630,705,'문403')]}
remove={104:[9],105:[4,9],107:[4,7],108:[15],109:[1,6,15],115:[6,10,11],116:[6,11],118:[9],119:[2,5,9,13],123:[4],125:[4,9],126:[5,15],130:[15],131:[4,6],132:[5],133:[15],134:[4,5],136:[5,15],137:[4,5,12],140:[14,15],141:[6,14,15],143:[5,15],144:[4,6,7],146:[15],147:[2,3,7,15],148:[15],149:[6],150:[6]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH};weeks[145]=[1,2,3,10,11,12];weeks[139]=[1,2,3,4,5,6,7,9,10,11,12]
explicitDates139={'2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-28','2026-11-04','2026-11-11','2026-11-18'}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exceptDates={146:{'2026-11-02','2026-11-04'}}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-101];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n],(n,c['sourceSchedule'],HH[n])
 for plan,z in zip(plans,x['plans']):
  assert c['campus']=='seoul' and plan['campus']=='서울';assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  normal=re.sub(r'\s+','',next(r[1] for r in basic if r[0]=='강의시간강의실'))
  for m in native:assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[0]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 def permitted(day):return day.isoformat() not in closed|exceptDates.get(n,set()) and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21) and (n!=139 or day.isoformat() in explicitDates139)
 meetings=[];independent=[]
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
 if n==139:assert {k[0] for k in independent}==explicitDates139
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':'서울','literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'explicitPhysicalDatesLiteral':sorted(explicitDates139) if n==139 else [],'independentDates':sorted({k[0] for k in independent}),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P/f'khu-{campus}-2026-2.packet002-physical-groups-prepared.json'));(P/f'packet003-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영 예외는 생성하지 않습니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  if c['sourceId']==xs[139-101]['originalWholeObject']['sourceId']:note+=' Global Capstone는 원문에 날짜가 명시된 대면 11일만 포함합니다. 선택 온라인 상담·최종 발표·보고서 제출 기한은 수업 시간을 생성하지 않습니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':3}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet003-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet003-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':1975,'baselineDates':36911,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':1975+len(selected),'totalDates':36911+count})
