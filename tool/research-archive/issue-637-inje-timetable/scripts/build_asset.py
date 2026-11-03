# 인나비 2026-2 학부 전체 목록(1,838행/1,756 코드·분반)과 수업계획서 XML 교육 필드로 inje-unknown-2026-2.json을 만든다.
# 교시→시각 공식 원문이 없으므로 모든 강좌는 scheduleStatus=unrecognized, schedules=[]로 둔다(시각 추정 금지).
import json,sys,os,hashlib,collections
raw,out=sys.argv[1],sys.argv[2]
rows=json.load(open(os.path.join(raw,'inje-native-all-public-rows-20261023.json')))
listsha=hashlib.sha256(open(os.path.join(raw,'navi-query-all-tr1.html'),'rb').read()).hexdigest()
byKey=collections.OrderedDict()
for r in rows: byKey.setdefault((r['교과목'],r['분반']),[]).append(r)
courses=[];stats=collections.Counter();conflicts=[]
for (code,sec),rs in byKey.items():
  rep=os.path.join(raw,'report-fields',f'{code}-{sec}.json')
  info=None;err=False
  if any(r['reportOnclick'] for r in rs):
    d=json.load(open(rep))
    if 'error' in d: err=True
    else:
      info=d['courseInformation']
      if info.get('교과목번호')!=code or info.get('분반')!=sec: raise SystemExit(f'XML key mismatch {code}-{sec}')
  depts=[];dc={};cr={}
  credits=float(rs[0]['학점'])
  for r in rs:
    if float(r['학점'])!=credits: raise SystemExit(f'credit conflict {code}-{sec}')
    for lab in [x.strip() for x in r['개설학과'].split(',') if x.strip()]:
      if lab in dc and dc[lab]!=r['이수구분']: conflicts.append((code,sec,lab,dc[lab],r['이수구분']))
      if lab not in dc: depts.append(lab); dc[lab]=r['이수구분']; cr[lab]=credits
  classes=sorted({r['이수구분'] for r in rs})
  sched=(info or {}).get('수업시간강의실','').strip()
  if err: reason='수업계획서 출력 서버 오류(XML 대신 \'AA문자열이나 이진 데이터는 잘립니다.\' 응답)'; stats['reportServerError']+=1
  elif info is None: reason='수업계획서 미등록(인나비 목록에 출력 버튼 없음)'; stats['noReport']+=1
  elif not sched: reason='수업계획서 수업시간·강의실 칸 비어 있음'; stats['emptySchedule']+=1
  else: reason='학부 교시→시각(HH:mm) 공식 원문 미확인'; stats['periodClockUnknown']+=1
  note=f'일정 보류: {reason}.' + (f' 수업계획서 원문 수업시간·강의실: {sched}' if sched else '')
  c={'sourceId':f'inje/all/2026-2/{code}-{sec}','campus':'unknown','academicYear':2026,'semester':'2',
     'courseCode':code,'courseName':rs[0]['교과목명'],'section':sec,'professor':rs[0]['담당교수'],
     'credits':credits,'departmentCredits':cr,'departments':depts,'departmentClassifications':dc,
     'departmentRemarks':{l:note+(' 같은 코드·분반이 목록에 두 행으로 실려 이수구분이 '+'·'.join(sorted({r['이수구분'] for r in rs}))+'로 다름(첫 행 값을 표시, 두 행 원문 모두 보존).' if any(x[0]==code and x[1]==sec and x[2]==l for x in conflicts) else '') for l in depts},
     'sourceSchedule':sched,'sourceClassroom':'','scheduleStatus':'unrecognized','schedules':[],
     'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},
     'sourceEducation':{'nativeRows':[{k:r[k] for k in ('sourceRow','이수구분','교과목','교과목명','분반','학점','담당교수','개설학과','성적부여방법')} for r in rs],
        'syllabusRegistered':any(r['reportOnclick'] for r in rs),
        'syllabusFields':{k:info.get(k,'') for k in ('과정','이수구분','이수학점','수강대상','수업시간강의실','집중이수강좌여부','수업방식_전체','사용언어')} if info else None,
        'holdReason':reason}}
  if not depts:
    c['classification']=classes[0] if len(classes)==1 else ''
    c['remarks']=note
    if len(classes)>1: conflicts.append((code,sec,'(개설학과 없음)',classes))
  courses.append(c)
data={'schemaVersion':1,'universityId':'inje','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2',
 'publishedDate':'2026-10-23','sourceUrl':'https://navi.inje.ac.kr/AllUsers/Lecture.aspx',
 'sourceNotice':'인나비 수업계획서 조회(2026학년도 2학기 [학부], 정규트랙, 학부전체) 2026-10-23 조회. 시간은 교시만 공개되어 시각 미확인.',
 'sourceSha256':listsha,'sourceRowCount':len(rows),'wholeSourceAcquired':True,'completionClaim':False,
 'campusScopeBasis':'학교 전체 조회 결과라 캠퍼스를 원문이 적지 않음; 강의실로 캠퍼스를 추정하지 않음','courses':courses}
json.dump(data,open(out,'w'),ensure_ascii=False,indent=2);open(out,'a').write('\n')
print(json.dumps({'courses':len(courses),'stats':stats,'conflicts':conflicts[:20],'nConflicts':len(conflicts)},ensure_ascii=False))
