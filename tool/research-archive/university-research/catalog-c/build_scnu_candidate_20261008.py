"""Published snapshot projection. No live-system completeness claim or inferred special dates."""
import json,re,collections,datetime,hashlib,pathlib
D=pathlib.Path(__file__).parent/'scnu-current-20261008'
def read(f):return json.loads((D/f).read_text())
def write(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
rows=read('educational-source-offerings.json');by=collections.defaultdict(list)
for r in rows:
 e=r['education'];by[e.get('코드',e.get('교과목코드')),e['분반']].append(r)
closed={(r['education']['과목코드'],r['education']['분반']) for r in read('closure-educational-rows.json')}
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
exams={str(datetime.date(2026,10,19)+datetime.timedelta(days=i)) for i in range(5)}
clock={p:((p+8)*60,(p+8)*60+50) for p in range(1,11)}
clock.update({11+i:(1080+i*50,1125+i*50) for i in range(5)})
pattern=re.compile(r'([월화수목금토일])(야간)?(\d+(?:,\d+)*)');courses=[];holds=[]
for (code,section),src in sorted(by.items()):
 if (code,section) in closed:continue
 fields={k:sorted({r['education'].get(k,'') for r in src}) for k in ['교과목명','강의시간','강의실','담당교수']}
 conflicts={k:v for k,v in fields.items() if len({re.sub(r'\s+','',x) for x in v})>1};e=src[0]['education'];tm=e.get('강의시간','');room=e.get('강의실','');reasons=[];blocks=[]
 if conflicts:reasons.append('native code/section duplicate conflicts: '+','.join(conflicts))
 compact=re.sub(r'\s+','',tm).replace('/','');matches=list(pattern.finditer(compact));remainder=pattern.sub('',compact)
 if remainder:reasons.append('native notation not fully resolved: '+remainder)
 if not matches:reasons.append('no published fixed weekday/period')
 for m in matches:
  periods=[int(x) for x in m[3].split(',')]
  if m[2] and any(p<11 for p in periods):periods=[p+10 for p in periods]
  for p in periods:
   if p not in clock:reasons.append('published period clock absent: '+str(p));continue
   start,end=clock[p];blocks.append({'weekday':'월화수목금토일'.index(m[1])+1,'nativePeriod':p,'startMinute':start,'endMinute':end,'classroom':room})
 if not room or re.search('미정|미배정|추후|협의',room):reasons.append('published classroom absent/unconfirmed')
 if not re.fullmatch(r'(?:[A-E]\d{5}|\d{3})',room):reasons.append('room notation needs meeting-specific interpretation')
 if re.search('집중|블렌디드|비대면|온라인|원격|현장|주-?\d|주차',e.get('교과목명','')+' '+tm):
  # 산림원격탐사 title describes subject matter, not delivery; keep explicitly held until course operation proof.
  reasons.append('special/field/remote/week-limited operation dates or mode unresolved')
 if any('별도 학사관리시스템' in str(r['sourceContext']) for r in src):reasons.append('source says external remote operation')
 meetings=[]
 if not reasons:
  for i in range(98):
   d=datetime.date(2026,9,1)+datetime.timedelta(days=i)
   if str(d) in holidays|exams:continue
   for b in blocks:
    if d.isoweekday()==b['weekday']:meetings.append({k:v for k,v in {**b,'date':str(d)}.items() if k!='nativePeriod'})
 categories=sorted({r['education'].get('이수구분',r['education'].get('영역','')) for r in src}-{''})
 contexts=list(dict.fromkeys(v for r in src for v in r['sourceContext']))
 deps=sorted({r['education'].get('협력학과',r['education'].get('담당학과',r['education'].get('수강대상학과',''))) for r in src}-{''})
 deps+=list(dict.fromkeys(r['sourceContext'][0] for r in src if r['sourceTable']>=48 and r['sourceContext']))
 deps=list(dict.fromkeys(deps));cat=categories[0] if len(categories)==1 else ''
 if not cat and src[0]['sourceTable']<37:cat=next((x for x in contexts if '교양' in x),'')
 group='전공' if any(x.startswith('전공') for x in categories) else '교직' if any('교직' in x or '교육실습'==x for x in categories) else '교양' if src[0]['sourceTable']<37 or '교양' in cat else ''
 units=sorted({next((v for k,v in r['education'].items() if k.startswith('학/이/실')),'') for r in src})
 credits=None
 if len(units)==1:
  m=re.match(r'(\d+(?:\.\d+)?)',units[0])
  if m:credits=float(m[1])
 remarks='2026-08-24 10:00 학교 공개 수업시간표의 정규 수업 계획입니다. 실제 출석·개별 휴강 확정이 아니며 실시간 시스템 변경 전체는 확인되지 않았습니다. 10/19~23 중간시험, 12/8~11 국·공휴일 보강, 12/14~18 기말시험은 강좌별 시각·강의실 미확인으로 일정에 포함하지 않았습니다. 개별 강좌 캠퍼스 미공개이며 대학 전체 자료 범위입니다. '
 remarks+='원문 수강조건: '+'; '.join(contexts)+'; '+'; '.join(k+': '+v for k,v in e.items() if k in {'수강대상','대상학년','학년','인원제한','사범대학이수시기','교직과정이수시기','수강대상학과'} and v)
 if reasons:remarks+=' 일정 미생성: '+'; '.join(dict.fromkeys(reasons))
 if reasons:holds.append({'nativeSubjectCode':code,'nativeSection':section,'reasons':list(dict.fromkeys(reasons)),'sourceConflicts':conflicts})
 courses.append({'sourceId':f'scnu-2026-2-{code}-{section}','referenceKind':'교과목코드','canonicalSubjectCodePublished':True,'nativeSectionPublished':True,'campus':'unknown','campusEvidence':'No per-offering campus field published; institution scope only. Room codes retained without deriving physical campus.','academicYear':2026,'semester':'2','courseCode':code,'courseName':e['교과목명'],'section':section,'professor':e.get('담당교수','') if '담당교수' not in conflicts else '', 'credits':credits,'classification':cat,'sourceClassificationAliases':categories,'classificationGroup':group,'departments':deps,'departmentCredits':{d:credits for d in deps} if credits is not None else {},'departmentClassifications':{},'departmentRemarks':{d:remarks for d in deps},'remarks':remarks,'sourceSchedule':tm,'sourceClassroom':room,'sourceScheduleAliases':fields['강의시간'],'sourceClassroomAliases':fields['강의실'],'scheduleStatus':'scheduled' if meetings else 'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'schedules':meetings,'nativePeriodBlocks':blocks,'publicEducationRows':src})
f='scnu-unknown-2026-2.published-partial-20261008.json';write(f,{'schemaVersion':2,'universityId':'scnu','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-24','sourceUrl':'https://www.scnu.ac.kr/aniculture/na/ntt/selectNttInfo.do?nttSn=281319202','courses':courses})
write('native-clock-proof.json',{'source':'notice-281319202-timetable-0824.hwp','section':1,'dayClockTable':3,'nightClockTable':4,'clocks':{str(k):v for k,v in clock.items()},'sourceDayClockCells':read('notice-281319202-timetable-0824.hwp.tables.json')[1]['tables'][3]['cells'],'sourceNightClockCells':read('notice-281319202-timetable-0824.hwp.tables.json')[1]['tables'][4]['cells'],'night16Published':False})
a={'completionClaim':False,'candidate':{'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()},'nativeRows':len(rows),'uniqueNativeCodeSectionCount':len(by),'closedNativeCodeSectionCount':len(closed),'closedSourceJoinCount':len(set(by)&closed),'closedAbsentInSnapshot':sorted(closed-set(by)),'closedStillPresent':sorted({(c['courseCode'],c['section']) for c in courses}&closed),'candidateClasses':len(courses),'scheduledClasses':sum(bool(c['schedules']) for c in courses),'datedMeetings':sum(len(c['schedules']) for c in courses),'holds':holds,'excludedHolidays':sorted(holidays),'excludedMidtermDates':sorted(exams),'ordinaryProjection':['2026-09-01','2026-12-07'],'semester':['2026-09-01','2026-12-18'],'currentPublicLookup':'Linked SUP named-course read-only form returned ErrorCode -200 need login; stopped.','unverified':['live-system current whole changes','week1/6/11 intensive exact operating dates','night period16/relative night6 clocks','course-specific exam/makeup time-room','external remote current offering codes','per-offering physical campus'],'productionChanged':False}
write('candidate-audit.json',a);print({k:a[k] for k in ['candidateClasses','scheduledClasses','datedMeetings','closedSourceJoinCount']})
