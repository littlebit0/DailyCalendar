import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent; xs=json.load(open(P/'packet001-50-full-source-prepared.json'))
# Manually reviewed original week/date/mode allocations. Only published physical groups.
weeks={1:[1,2,3,6,7,10,11,13],3:[1,2,3,4,5,10,11,12,13,15],4:[1,3,4,6,7,9,10,11,12,13,14],5:[2,3,6,7,11,13,15],6:[1,2,3,6,7,11,13,15],8:[1,2,3,6,7,10,11,13,15],9:[1,2,3,6,7,10,11,12],30:[1,2,3,4,5,6,7,9,10,11,12,13,14],39:[1,3,5,6,7,9,10]}
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)'); closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
proof=[]; selected={}; sha={}; count=0
for n,ws in weeks.items():
 x=xs[n-1];c=x['originalWholeObject']; ps=x['plans'];assert len(ps)==1
 plan=ps[0]['originalWholeEducationPlan'];assert plan['header']==['2026학년도 2학기 강의계획서'];assert plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd'];assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
 basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
 native=list(slot.finditer(c['sourceSchedule']));assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']));normal=re.sub(r'\s+','',next(r[1] for r in basic if r[0]=='강의시간강의실'))
 for m in native:assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal
 rows=next(s['rows'] for s in plan['educationalSections'] if s['section']=='주별강의내용'); own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])}
 spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 meetings=[]
 for m in native:
  wd='월화수목금토일'.index(m[1])+1;st=int(m[2])*60+int(m[3]);en=int(m[4])*60+int(m[5]);room=m[6].strip()
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and day.isoformat() not in closed and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':st,'endMinute':en,'classroom':room})
    day+=dt.timedelta(days=1)
 assert meetings
 # Independent weekly anchor recomputation, separate traversal.
 keys=set()
 for a,b,r in spans:
  for m in native:
   wd='월화수목금토일'.index(m[1])+1;day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if day.isoformat() not in closed and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21):keys.add((day.isoformat(),wd,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()))
    day+=dt.timedelta(days=7)
 assert keys=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings};assert len(keys)==len(meetings)
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'sourceId':c['sourceId'],'packetIndex':n,'nativeClock':c['sourceSchedule'],'allowedPhysicalWeeksLiteral':ws,'originalFullPlan':plan,'physicalWeekRows':[s[2] for s in spans],'recordedAndUnknownLiveHoursGenerated':0,'dates':sorted({r['date'] for r in meetings}),'newCount':len(meetings),'allUserModesPreserved':True})
 sha[ps[0]['file']]=hashlib.sha256(pathlib.Path(ps[0]['file']).read_bytes()).hexdigest()
for campus in ['seoul','global']:
 file=pathlib.Path('assets/timetable')/f'khu-{campus}-2026-2.json';old=json.load(open(file));(P/f'prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 원문에 대면으로 표시된 주간 또는 명시 대면 기본 중 개별 원격 예외를 제외한 부분만 예약합니다. 녹화·방식 미확정 비대면·시험·빈 주차는 시간표에 생성하지 않습니다. 원문 전체 날짜·운영 문구는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':1}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet001-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet001-nine-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':9,'addedDates':count,'proofs':proof,'originalPlanSHA256':sha,'originalWholeScheduledPreserved':1947,'originalDatesPreserved':36548,'scope':'Prepared physical portion only; live/recorded raw retained, not generated. Source-specific weekly actual date spans, no ordinal-to-calendar inference.'},ensure_ascii=False,indent=2)+'\n');print({'added':9,'dates':count,'total':1956,'allDates':36548+count})
