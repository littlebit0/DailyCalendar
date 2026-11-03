"""Current public undergraduate source, exact native references and conservative weekly reservations."""
from pathlib import Path
import json,re,datetime,collections,copy
P=Path(__file__).parent
read=lambda f:json.loads(Path(f).read_text())
save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
rows=read(P/'current-undergraduate-native-2820-row-variants.json');groups=collections.defaultdict(list)
for r in rows:groups[r['nativeOffering']].append(r)
oldpath=P.parent/'kongju-cheonan-2026-2.reservation-planned-v1.json';(P/'baseline-cheonan65-frozen.json').write_bytes(oldpath.read_bytes());baseline=read(oldpath);old={c['courseCode']+c['section']:c for c in baseline['courses']}
closures=read(P.parent/'kongju-2026-2-closures-education-v1.json');save('current-native-closures-education.json',closures)
closed={r['nativeCourseCode']+r['nativeSection'] for r in closures['rows']}
source=read(P/'current-whole-undergraduate-lecture-education.json');table=source['clockAndCampusTables'][2];cells=table['cells']
def at(row,col):
 hits=[c for c in cells if c['row']<=row<c['row']+c['rowSpan'] and c['col']<=col<c['col']+c['colSpan']];return hits[-1]['text'] if hits else ''
aliases=collections.defaultdict(set)
for row in range(1,40):
 for offset in [0,4]:
  campusraw=re.sub(r'\s','',at(row,offset));campus='singwan' if '신관' in campusraw else 'cheonan' if '천안' in campusraw else 'yesan' if '예산' in campusraw else None
  if not campus:continue
  for val in [at(row,offset+2),at(row,offset+3)]:
   val=re.sub(r'\s','',val)
   if val:aliases[val].add(campus)
aliases=dict(aliases);save('direct-current-campus-building-aliases.json',{a:sorted(v) for a,v in aliases.items()})
def campus_for(room):
 s=re.sub(r'\s','',room).strip('()');matches=[]
 for alias in sorted(aliases,key=len,reverse=True):
  if alias in s:matches.append((alias,aliases[alias]))
 if not matches:return 'unknown'
 biggest=[m for m in matches if not any(m[0]!=z[0] and m[0] in z[0] for z in matches)]
 residue=s
 for alias,_ in biggest:residue=residue.replace(alias,'')
 if re.sub(r'[\d\W_]|강의실|호|관','',residue):return 'unknown'
 mapped=set().union(*(v for a,v in biggest));return next(iter(mapped)) if len(mapped)==1 else 'multiple'
def parse(text):
 s=re.sub(r'\s','',text);blocks=[]
 if not s:return [],'noPublishedWeekdayPeriod'
 if re.search(r'[^월화수목금토일\d,/\-~.]',s):return [],'nativeNonRegularTiming'
 matches=list(re.finditer(r'([월화수목금토일])([^월화수목금토일]*)',s))
 if not matches or matches[0].start()!=0:return [],'unrecognizedLiteralPeriodSyntax'
 for m in matches:
  value=m[2].strip(',/');periods=[]
  for item in value.split(','):
   if not item:continue
   if re.fullmatch(r'\d+[-~]\d+',item):
    a,b=map(int,re.split('[-~]',item));periods.extend(range(a,b+1))
   elif item.isdigit():periods.append(int(item))
   else:return [],'unrecognizedLiteralPeriodSyntax'
  if not periods:return [],'unrecognizedLiteralPeriodSyntax'
  if any(p>9 for p in periods):return [],'normalDayPeriod10plusNotPublishedOrNightScopeUnknown'
  periods=sorted(set(periods));runs=[]
  for p in periods:
   if not runs or p!=runs[-1][-1]+1:runs.append([p])
   else:runs[-1].append(p)
  for ps in runs:blocks.append({'weekday':'월화수목금토일'.index(m[1])+1,'startMinute':(8+ps[0])*60,'endMinute':(8+ps[-1])*60+50,'nativePeriods':ps})
 return blocks,None
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
start=datetime.date(2026,9,1);end=datetime.date(2026,12,7);exams=(datetime.date(2026,10,20),datetime.date(2026,10,26))
new=[];audit=[]
for code,rs in groups.items():
 if code in old:
  audit.append({'nativeOffering':code,'adjudication':'preservedExistingContract65Object','sourceVariants':len(rs),'existingSourceId':old[code]['sourceId']});continue
 r=rs[0];sig={tuple(v[k] for k in ['courseTitle','professor','credits','periodRaw','roomRaw']) for v in rs};reasons=[]
 if len(sig)>1:reasons.append('sameNativeSourceVariantsClockRoomOrTeacherConflict')
 if code in closed:reasons.append('currentPublishedClosure')
 blocks,reason=parse(r['periodRaw'])
 if reason:reasons.append(reason)
 if not r['roomRaw']:reasons.append('actualRoomUnpublished')
 operating=' '.join(v['remarks']+' '+v['periodRaw'] for v in rs)
 if re.search(r'원격|온라인|이러닝|비대면|OCU|동영상|사이버',operating):reasons.append('remoteOrAsynchronousOperationNotActuallyAllocated')
 if re.search(r'블록|집중|현장실습|교육봉사|현장교육실습|병원실습|임상실습|산업체승인|사업주',operating+' '+r['courseTitle']):reasons.append('individualFieldIntensiveOrBlockOperatingBoundsUnknown')
 campus=campus_for(r['roomRaw']);sourceid=f'kongju/current-public/2026/2/{code}'
 dept=[]
 for v in rs:
  heads=[x for x in v['sourceContext'] if re.search(r'^\d+(?:-\d+)?\.\s*',x) and re.search(r'(?:과|학부|전공|교직)(?:\s*\[\])?$',x)]
  dep=re.sub(r'^\d+(?:-\d+)?\.\s*','',heads[-1]).replace('[]','').strip() if heads else ''
  if dep and dep not in dept:dept.append(dep)
 classification=r['classification']
 if classification=='〃':classification=''
 note='공개 정규 주간 예약 계획이며 실제 개별 출석일 확정 자료가 아닙니다. 학기 내 변경/보강/실제 시험시간은 개별 확인 필요. 원문 9자리 과목번호를 그대로 보존하며 별도 학수번호/분반 정의는 미확인입니다.'
 if reasons:note+=' 보류: '+', '.join(reasons)
 schedules=[]
 if not reasons:
  day=start
  while day<=end:
   date=day.isoformat()
   if date not in holidays and not exams[0]<=day<=exams[1]:
    for b in blocks:
     if day.isoweekday()==b['weekday']:schedules.append({'date':date,'weekday':b['weekday'],'startMinute':b['startMinute'],'endMinute':b['endMinute'],'classroom':r['roomRaw']})
   day+=datetime.timedelta(days=1)
 c={'sourceId':sourceid,'universityId':'kongju','campus':campus,'academicYear':2026,'semester':'2','courseCode':code,'section':'','courseName':r['courseTitle'],'professor':r['professor'],'credits':float(r['credits']) if re.fullmatch(r'\d+(?:\.\d+)?',r['credits']) else None,'classification':classification,'sourceSchedule':r['periodRaw'],'sourceClassroom':r['roomRaw'],'scheduleStatus':'scheduled' if schedules else 'unrecognized','schedules':schedules,'period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'departments':dept,'departmentCredits':{d:float(r['credits']) for d in dept if re.fullmatch(r'\d+(?:\.\d+)?',r['credits'])},'departmentClassifications':{d:classification for d in dept},'departmentRemarks':{d:note for d in dept},'remarks':note,'sourceEducationalMetadata':{'native9DigitOffering':code,'nativeNumericSectionUnpublished':True,'originalPublishedRowVariants':rs,'exactSourcePeriodicBlocks':blocks,'holdReasons':reasons,'campusProof':'currentOfficialBuildingAliasTable214' if campus!='unknown' else 'noCompletePhysicalCampusMapping','sourcePublicationDate':'2026-07-31','wholeLatestChangesConfirmed':False}}
 new.append(c);audit.append({'nativeOffering':code,'sourceId':sourceid,'campus':campus,'eligible':bool(schedules),'holdReasons':reasons,'meetings':len(schedules),'variants':len(rs)})
courses=list(old.values())+new
for campus in ['singwan','cheonan','yesan','multiple','unknown']:
 ds=copy.deepcopy(baseline);ds.update({'campus':campus,'campusName':{'singwan':'신관캠퍼스','cheonan':'천안캠퍼스','yesan':'예산캠퍼스','multiple':'복수 캠퍼스','unknown':'캠퍼스 미확인'}[campus],'sourceUrl':'https://www.kongju.ac.kr/bbs/KNU/2128/429677/artclView.do','candidateRevision':'current-whole-undergraduate-ordinary-v2','completionClaim':False,'courses':[c for c in courses if c['campus']==campus]});save(f'kongju-{campus}-2026-2.current-whole-ordinary-v2.json',ds)
save('whole-adjudication-audit.json',{'originalCurrentNative2674':len(groups),'sourceEducationRows2820':len(rows),'preservedPrior65':len(old),'priorCurrentOverlap64':sum(c in old for c in groups),'wholeDistinctIncludingPrior':len(courses),'newCourses':len(new),'newEligible':sum(bool(c['schedules']) for c in new),'newMeetings':sum(len(c['schedules']) for c in new),'heldReasonCounts':dict(collections.Counter(reason for a in audit for reason in a.get('holdReasons',[]))),'adjudications':audit,'actualTests':'pending','completionClaim':False})
print('whole',len(courses),'newEligible',sum(bool(c['schedules']) for c in new),'newdates',sum(len(c['schedules']) for c in new));print(collections.Counter(reason for a in audit for reason in a.get('holdReasons',[])));print('campus',collections.Counter(c['campus'] for c in courses))
