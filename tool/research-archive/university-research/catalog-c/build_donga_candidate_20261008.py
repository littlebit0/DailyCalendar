"""Official public snapshot; only educational fields, never live-system completeness."""
import collections, datetime, hashlib, json, pathlib, re
import openpyxl
D=pathlib.Path(__file__).parent/'donga-current-20261008'
def write(f,x):
 (D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
rows=json.loads((D/'public-education-37448.json').read_text())['rows']
by=collections.defaultdict(list)
for r in rows:
 e=r['education'];by[str(e['교과목 코드']),str(e['분반'])].append(r)
closed=set();closure=[]
x=json.loads(pathlib.Path('work/university-research/catalog-e/donga-closed-rows.json').read_text())
for f,sheets in x.items():
 for s in sheets:
  for r in s['data'][4:]:
   if len(r)>7 and r[5] and r[7]:
    code=str(r[5]);section=str(r[7]).zfill(2)
    if re.fullmatch('[A-Z0-9]{8}',code):closed.add((code,section));closure.append({'source':f,'nativeSubjectCode':code,'nativeSection':section,'courseName':r[6],'nativeClassification':r[8],'credits':r[9]})
write('closure-educational-rows.json',closure)
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
midterm={str(datetime.date(2026,10,20)+datetime.timedelta(days=i)) for i in range(7)}
makeups={'2026-09-24':'2026-12-10','2026-09-25':'2026-12-11','2026-10-05':'2026-12-08','2026-10-09':'2026-12-09'}
clock={3:[540,615],6:[630,705],9:[720,795],12:[810,885],15:[900,975],18:[990,1065],21:[1080,1150],24:[1155,1225],27:[1230,1300]}
pattern=re.compile(r'([월화수목금토일])\s*(\d+)\s*[~\-]\s*(\d+)교시')
courses=[];holds=[]
for (code,sec),src in sorted(by.items()):
 if (code,sec) in closed:continue
 e=src[0]['education'];dsu=str(e['교과목명(국문)']).startswith('(DSU)')
 conflicts={k:sorted({str(r['education'].get(k)) for r in src}) for k in ['교과목명(국문)','학점','이론','실습','수업운영방식','수업요일/시간','수업장소','교강사 및 담당주차'] if len({str(r['education'].get(k)) for r in src})>1}
 reasons=[];blocks=[]
 tm=e['수업요일/시간'];room=e['수업장소'];notes='\n'.join(dict.fromkeys(str(r['education'].get('비고') or '') for r in src))
 if conflicts:reasons.append('duplicate native code/section differing educational fields')
 if dsu:reasons.append('external Dongseo operation/calendar/instruction-break policy not independently resolved')
 if str(e['수업운영방식'])!='오프라인':reasons.append('online/mixed operation needs actual synchronous clock and week/date proof')
 if str(e['학점'])!='3' or str(e['이론'])!='3' or str(e['실습'])!='0':reasons.append('50-minute/practice actual instruction and rest split not proved per offering')
 matches=list(pattern.finditer(str(tm)))
 if len(matches)!=2 or len({m[1] for m in matches})!=2:reasons.append('not the published two different weekday 75-minute format')
 if re.search(r'집중|주차|[0-9]주|필드\(|산업체',str(tm)+str(room)+notes):reasons.append('week-specific/field/intensive operation cannot be expanded as weekly reservation')
 rooms=re.findall(r'S[0-9]{2}-[A-Z0-9\-]+\(승학\)',str(room))
 if len(rooms)!=2:reasons.append('meeting-specific classroom/campus pair not proved')
 for i,m in enumerate(matches):
  start=int(m[2]);end=int(m[3]);day='월화수목금토일'.index(m[1])+1
  if start not in clock or end!=start+2:reasons.append('actual 75-minute clock group not proved');continue
  blocks.append({'weekday':day,'nativePeriods':[start,start+1,start+2],'startMinute':clock[start][0],'endMinute':clock[start][1],'classroom':rooms[i].removesuffix('(승학)') if i<len(rooms) else ''})
 meetings=[]
 if not reasons:
  for i in range(98):
   day=datetime.date(2026,9,1)+datetime.timedelta(days=i)
   if str(day) in holidays|midterm:continue
   for b in blocks:
    if day.isoweekday()==b['weekday']:meetings.append({k:v for k,v in {**b,'date':str(day)}.items() if k!='nativePeriods'})
  # Guide explicitly says original course periods and existing classroom on these published makeup dates.
  for original,target in makeups.items():
   day=datetime.date.fromisoformat(original);actual=datetime.date.fromisoformat(target)
   for b in blocks:
    if day.isoweekday()==b['weekday']:meetings.append({**{k:v for k,v in b.items() if k!='nativePeriods'},'weekday':actual.isoweekday(),'date':target,'sourceOriginalDate':original})
 nativecampus='승학' if '(승학)' in str(room) and '주례' not in str(room) else '주례' if '주례' in str(room) else '센텀' if '센텀' in str(room) else 'unknown'
 remark='2026-09-03 수정 공개 연합전공 개설교과목 일부입니다. 전체 대학·실시간 시스템 변경 완전성은 확인되지 않았습니다. 신청한 연합전공 모듈 교과목만 수강 가능하며 수업계획서 확인이 필요합니다. 원문 예약표시와 실제 75분 수업 종료를 구분했습니다. 10/20~26 중간시험과 12/12~18 기말시험 일정은 강좌별 미확인으로 제외했습니다. 공식 보강표는 원 수업 교시·기존 강의실을 명시하며 변경된 실제 요일을 보존했습니다. '
 remark+='이수구분(전공필수·전공선택) 미공개이며 분류에는 원문 편성모듈을 보존했습니다. 운영방식: '+str(e['수업운영방식'])+'; 원문 비고: '+notes+'; 캠퍼스 원문: '+nativecampus
 if reasons:remark+='; 일정 미생성: '+'; '.join(dict.fromkeys(reasons))
 deps=list(dict.fromkeys(r['sheet'] for r in src))
 c={'sourceId':f'donga-2026-2-{code}-{sec}','referenceKind':'교과목코드','canonicalSubjectCodePublished':True,'nativeSectionPublished':True,'campus':'unknown','nativeCampus':nativecampus,'campusEvidence':'Source-specific physical campus retained; candidate institutional scope includes external university/online courses, not a physical main-campus assignment.','academicYear':2026,'semester':'2','courseCode':code,'courseName':e['교과목명(국문)'],'section':sec,'professor':e.get('교강사 및 담당주차') or '', 'credits':e['학점'],'classification':str(e['편성모듈']),'sourceClassificationAliases':list(dict.fromkeys(str(r['education']['편성모듈']) for r in src)),'classificationGroup':'전공','departments':deps,'departmentCredits':{d:e['학점'] for d in deps},'departmentClassifications':{},'departmentRemarks':{d:remark for d in deps},'remarks':remark,'sourceSchedule':tm,'sourceClassroom':room,'scheduleStatus':'scheduled' if meetings else 'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'schedules':meetings,'nativePeriodBlocks':blocks,'publicEducationRows':src}
 courses.append(c)
 if reasons:holds.append({'nativeSubjectCode':code,'nativeSection':sec,'reasons':list(dict.fromkeys(reasons)),'sourceConflicts':conflicts})
f='donga-institution-2026-2.published-partial-20261008.json'
write(f,{'schemaVersion':2,'universityId':'donga','campus':'unknown','campusName':'대학 전체 공개 일부(외부 운영 포함)','academicYear':2026,'semester':'2','publishedDate':'2026-09-03','sourceUrl':'https://wwwnew.donga.ac.kr/article/bbs-62/8464209?from=%2Fcommunity%2Facademic-notices','courses':courses})
write('candidate-audit.json',{'completionClaim':False,'candidate':{'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()},'nativeRows':len(rows),'uniqueNativeClasses':len(by),'candidateClasses':len(courses),'scheduledClasses':sum(bool(c['schedules']) for c in courses),'datedMeetings':sum(len(c['schedules']) for c in courses),'closedIdentities':len(closed),'closedJoin':sorted(set(by)&closed),'holds':holds,'actual75MinuteGroups':clock,'excludedHolidays':sorted(holidays),'excludedMidtermDates':sorted(midterm),'ordinaryProjection':['2026-09-01','2026-12-07'],'makeups':makeups,'productionChanged':False})
print({k:v for k,v in json.loads((D/'candidate-audit.json').read_text()).items() if k in ['nativeRows','uniqueNativeClasses','candidateClasses','scheduledClasses','datedMeetings','closedIdentities','closedJoin']})
