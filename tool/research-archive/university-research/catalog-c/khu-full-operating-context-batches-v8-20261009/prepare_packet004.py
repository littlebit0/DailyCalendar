# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet004-50-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={
151: [(4, 900, 1065, '문402')],
152: [(2, 630, 705, '문401'), (4, 630, 705, '문401')],
153: [(2, 630, 705, '문308'), (4, 630, 705, '문308')],
154: [(1, 630, 705, '문402'), (3, 630, 705, '문402')],
155: [(1, 720, 795, '문403'), (3, 720, 795, '문403')],
156: [(1, 540, 615, '동301'), (3, 540, 615, '동301')],
157: [(1, 720, 795, '문308'), (3, 720, 795, '문308')],
158: [(4, 810, 975, '문401')],
159: [(1, 900, 1065, '문303')],
160: [(1, 630, 705, '동301'), (3, 630, 705, '동301')],
162: [(2, 630, 705, '문309'), (4, 630, 705, '문309')],
164: [(4, 720, 885, '문406')],
165: [(5, 720, 885, '문304')],
166: [(3, 720, 885, '동301')],
167: [(2, 630, 705, '문310'), (4, 630, 705, '문310')],
168: [(2, 900, 1065, '문304')],
171: [(1, 630, 705, '문305'), (3, 630, 705, '문305')],
172: [(1, 720, 795, '문305'), (3, 720, 795, '문305')],
174: [(2, 900, 975, '문305'), (4, 900, 975, '문305')],
175: [(2, 990, 1065, '문302'), (4, 990, 1065, '문302')],
176: [(1, 540, 615, '문302'), (3, 540, 615, '문302')],
177: [(2, 990, 1065, '문305'), (4, 990, 1065, '문305')],
178: [(1, 900, 975, '오309'), (3, 900, 975, '오309')],
179: [(1, 990, 1065, '오309'), (3, 990, 1065, '오309')],
180: [(1, 810, 885, '오422'), (3, 810, 885, '오422')],
181: [(1, 900, 975, '오422'), (3, 900, 975, '오422')],
182: [(2, 810, 885, '오309'), (4, 810, 885, '오309')],
183: [(2, 900, 975, '오309'), (4, 900, 975, '오309')],
184: [(1, 540, 615, '오422'), (3, 540, 615, '오422')],
185: [(1, 630, 705, '오422'), (3, 630, 705, '오422')],
186: [(1, 990, 1065, '오252'), (3, 990, 1065, '오252')],
187: [(2, 900, 975, '오252'), (4, 900, 975, '오252')],
188: [(1, 720, 795, '오252'), (3, 720, 795, '오252')],
189: [(5, 900, 1065, '오252')],
190: [(5, 540, 705, '오209')],
191: [(5, 900, 1065, '오213')],
192: [(1, 540, 615, '오202'), (3, 540, 615, '오202')],
193: [(1, 630, 705, '오202'), (3, 630, 705, '오202')],
194: [(5, 900, 1065, '오422')],
195: [(2, 720, 795, '오210'), (4, 720, 795, '오210')],
198: [(2, 900, 975, '오103'), (4, 900, 975, '오103')],
199: [(1, 900, 975, '오212'), (3, 900, 975, '오212')],
200: [(1, 990, 1065, '오212'), (3, 990, 1065, '오212')]}
remove={151: [15], 153: [15], 154: [15], 155: [15], 156: [6], 157: [15], 159: [5], 160: [14, 15], 162: [3, 11], 164: [4], 165: [4, 6], 166: [15], 168: [9], 176: [15], 177: [15], 182: [15], 183: [15], 186: [15], 187: [15], 188: [15], 189: [14, 15], 190: [15], 191: [15], 192: [15], 193: [15], 194: [4, 6], 198: [15]}
weeks={n:[w for w in W if w not in remove.get(n,[])] for n in HH}
explicitWednesdayDates={"2026-09-02","2026-09-09","2026-09-16","2026-09-23","2026-09-30","2026-10-07","2026-10-14","2026-10-28","2026-11-04","2026-11-11","2026-11-18","2026-11-25","2026-12-02","2026-12-09"}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};exceptDates={152:{'2026-12-10'}}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-151];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 def permitted(day):return day.isoformat() not in closed|exceptDates.get(n,set()) and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21) and (n not in [199,200] or day.isoformat() in explicitWednesdayDates)
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
 if n in [199,200]:assert {k[0] for k in independent}==explicitWednesdayDates
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':'서울','literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'explicitPhysicalDatesLiteral':sorted(explicitWednesdayDates) if n in [199,200] else [],'independentDates':sorted({k[0] for k in independent}),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P/f'khu-{campus}-2026-2.packet003-physical-groups-prepared.json'));(P/f'packet004-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영 예외는 생성하지 않습니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  if c['sourceId'] in {xs[199-151]['originalWholeObject']['sourceId'],xs[200-151]['originalWholeObject']['sourceId']}:note+=' 관리회계1은 원문에 대면 운영 변경과 기존 주초 영상 기술이 함께 남아 있어 확정 수요일 대면 14일만 포함합니다. 월요일 운영은 추정하지 않습니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':4}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet004-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet004-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2011,'baselineDates':37488,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2011+len(selected),'totalDates':37488+count})
