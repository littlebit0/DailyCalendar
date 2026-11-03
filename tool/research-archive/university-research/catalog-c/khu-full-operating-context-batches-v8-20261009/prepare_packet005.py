# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet005-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={201: [(5, 540, 705, '오201')],
 202: [(1, 540, 615, '오308'), (3, 540, 615, '오308')],
 203: [(1, 810, 885, '오212'), (3, 810, 885, '오212')],
 204: [(1, 630, 705, '오423'), (3, 630, 705, '오423')],
 205: [(2, 900, 975, '오422'), (4, 900, 975, '오422')],
 206: [(1, 630, 705, '오201'), (3, 630, 705, '오201')],
 207: [(1, 900, 975, '오201'), (3, 900, 975, '오201')],
 208: [(1, 990, 1065, '오201'), (3, 990, 1065, '오201')],
 209: [(2, 630, 705, '오401'), (4, 630, 705, '오401')],
 210: [(2, 810, 885, '오401'), (4, 810, 885, '오401')],
 211: [(5, 900, 1065, '오307')],
 213: [(1, 630, 705, '오254'), (3, 630, 705, '오254')],
 214: [(5, 780, 945, '오211')],
 215: [(3, 540, 650, '스B101(계단)')],
 216: [(1, 900, 975, '스111(세미나실)'), (3, 900, 975, '스111(세미나실)')],
 217: [(2, 720, 885, '스B102'), (4, 960, 1070, '스B102')],
 220: [(3, 1080, 1245, '스B111')],
 221: [(2, 810, 885, '스111(세미나실)'), (4, 810, 885, '스111(세미나실)')],
 222: [(1, 810, 885, '스111(세미나실)'), (3, 810, 885, '스111(세미나실)')],
 223: [(1, 900, 975, '스B113(계단)'), (3, 900, 975, '스B113(계단)')],
 225: [(2, 630, 705, '스B101(계단)'), (4, 630, 705, '스B101(계단)')],
 226: [(1, 900, 975, '스B114(계단)'), (3, 900, 975, '스B114(계단)')],
 227: [(4, 810, 1040, '스B217')],
 229: [(1, 900, 975, '스B108'), (3, 900, 975, '스B108')],
 230: [(1, 810, 885, '스B101(계단)'), (3, 810, 885, '스B101(계단)')],
 231: [(1, 540, 615, '스B113(계단)'), (3, 540, 615, '스B113(계단)')],
 232: [(1, 630, 705, '스B103'), (3, 630, 705, '스B103')],
 233: [(1, 810, 885, '스B104'), (3, 810, 885, '스B104')],
 234: [(1, 990, 1065, '스B103'), (3, 990, 1065, '스B103')],
 235: [(1, 630, 705, '스B104'), (3, 630, 705, '스B104')],
 236: [(1, 810, 885, '스B103'), (3, 810, 885, '스B103')],
 237: [(1, 900, 975, '스B102'), (3, 900, 975, '스B102'), (5, 720, 830, '스B102')],
 238: [(2, 540, 615, '스B103'), (4, 540, 615, '스B103')],
 239: [(2, 630, 705, '스B103'), (4, 630, 705, '스B103')],
 240: [(5, 780, 945, '스B104')],
 241: [(2, 720, 795, '스B103'), (4, 720, 795, '스B103')],
 242: [(2, 900, 975, '스B104'), (4, 900, 975, '스B104')],
 243: [(1, 810, 920, '스B207'), (3, 810, 920, '스B207')],
 244: [(2, 810, 885, '스B109'), (4, 810, 885, '스B109')],
 245: [(2, 990, 1100, '스B210-2'), (4, 990, 1100, '스B210-2')],
 246: [(1, 810, 885, '스B111'), (3, 810, 885, '스B111')],
 248: [(2, 540, 650, '스220(계단)')],
 249: [(2, 660, 770, '스222(계단)')],
 250: [(4, 540, 650, '스320')]}
remove={201: [4, 6], 203: [15], 205: [14, 15], 206: [15], 207: [15], 208: [15], 211: [4, 6], 214: [4, 6], 216: [10], 217: [15], 220: [14, 15], 225: [6, 10], 226: [9], 240: [6], 245: [4, 5, 15], 250: [4, 15]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH}
weeks[243]=[2,3,9,10]
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exceptDates={230:{'2026-12-14'},235:{'2026-11-16'},236:{'2026-11-16'}}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-201];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 def permitted(day):return day.isoformat() not in closed|exceptDates.get(n,set()) and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21)
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
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':'서울','literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P/f'khu-{campus}-2026-2.packet004-physical-groups-prepared.json'));(P/f'packet005-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영 예외는 생성하지 않습니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':5}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet005-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet005-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2054,'baselineDates':38420,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2054+len(selected),'totalDates':38420+count})
