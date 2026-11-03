"""Preserve frozen public v2/cell objects; add direct native reservation windows only."""
import copy, datetime, hashlib, json, pathlib, re
ROOT=pathlib.Path(__file__).resolve().parents[4]
BASE=ROOT/'work/university-research/catalog-c'
OUT=pathlib.Path(__file__).parent
INPUTS=[BASE/'donga-campus-v2-20261008/donga-seunghak-2026-2.published-partial-v2-20261008.json',BASE/'donga-campus-v2-20261008/donga-unknown-2026-2.published-partial-v2-20261008.json',BASE/'donga-cell-extension-20261008/donga-unknown-cell-2026-2.published-partial-20261008.json']
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
midterm={str(datetime.date(2026,10,20)+datetime.timedelta(days=i)) for i in range(7)}
makeups={'2026-09-24':'2026-12-10','2026-09-25':'2026-12-11','2026-10-05':'2026-12-08','2026-10-09':'2026-12-09'}
clock=re.compile(r'\(([월화수목금토일])\s*(\d{1,2}):(\d{2})\s*[~\-]\s*(\d{1,2}):(\d{2})\)')
period=re.compile(r'([월화수목금토일])\s*(\d+)\s*[~\-]\s*(\d+)교시')
conflictingTheory={('01B40007','01'),('01B40010','01'),('01B40011','01'),('01B40029','01'),('01HCC309','01'),('01EPS304','01')}
new=[];ids=[];original=[];expanded=[]
for p in INPUTS:
 d=json.loads(p.read_text());original.extend(d['courses'])
 for c in d['courses']:
  x=copy.deepcopy(c)
  if not x['schedules'] and x.get('publicEducationRows') and 'education' in x['publicEducationRows'][0]:
   source=x['publicEducationRows'];e=source[0]['education']
   operational=['교과목명(국문)','학점','이론','실습','수업운영방식','수업요일/시간','수업장소','교강사 및 담당주차']
   conflict=any(len({json.dumps(r['education'].get(k),ensure_ascii=False) for r in source})>1 for k in operational)
   tm=str(e.get('수업요일/시간') or '');room=str(e.get('수업장소') or '');notes='\n'.join(str(r['education'].get('비고') or '') for r in source)
   matches=list(clock.finditer(tm));ps=list(period.finditer(tm));rooms=re.findall(r'S[0-9]{2}-[A-Z0-9\-]+\(승학\)',room)
   eligible=((x['courseCode'],x['section']) not in conflictingTheory and not conflict and e.get('수업운영방식')=='오프라인' and not str(e.get('교과목명(국문)')).startswith('(DSU)') and not re.search(r'집중|주차|[0-9]주|산업체',tm+room+notes) and len(matches) in (1,2) and len(matches)==len(rooms)==len(ps))
   blocks=[]
   if eligible:
    for i,m in enumerate(matches):
     day='월화수목금토일'.index(m[1])+1;start=int(m[2])*60+int(m[3]);end=int(m[4])*60+int(m[5]);q=ps[i];a=int(q[2]);b=int(q[3])
     expectedStart=480+(a-1)*30 if a<=20 else 1080+(a-21)*25
     expectedEnd=480+b*30 if b<=20 else 1080+(b-20)*25
     assert q[1]==m[1] and start==expectedStart and end==expectedEnd and end>start,(x['sourceId'],q.groups(),m.groups())
     blocks.append({'weekday':day,'nativePeriods':list(range(a,b+1)),'startMinute':start,'endMinute':end,'classroom':rooms[i].removesuffix('(승학)')})
    plans=[]
    for offset in range(98):
     day=datetime.date(2026,9,1)+datetime.timedelta(days=offset)
     if str(day) in holidays|midterm:continue
     for b in blocks:
      if day.isoweekday()==b['weekday']:plans.append({**{k:v for k,v in b.items() if k!='nativePeriods'},'date':str(day)})
    for originalDate,target in makeups.items():
     for b in blocks:
      if datetime.date.fromisoformat(originalDate).isoweekday()==b['weekday']:plans.append({**{k:v for k,v in b.items() if k!='nativePeriods'},'weekday':datetime.date.fromisoformat(target).isoweekday(),'date':target,'sourceOriginalDate':originalDate})
    x['schedules']=plans;x['scheduleStatus']='scheduled';x['nativePeriodBlocks']=blocks
    note='현재 개별 공개 요일·HH:mm·승학 강의실의 정규 예약 계획입니다. 원문 예약 범위를 그대로 보존하며 휴식 포함 가능; 실제 수업분량/출석/강좌별 시험·보강 및 최신 변경 확인 완료를 뜻하지 않습니다. 일반 75분제 규칙만으로 개별 공개 3시간 예약을 분할하거나 종료시각을 발명하지 않았습니다. 원문 Field/BITS 명칭과 수강 제한은 그대로이며 개별 집중/외부/온라인/주차별 운영이 명시된 다른 강좌는 보류했습니다. 운영 방식 override는 미지정으로 사용자 선택을 유지합니다. '
    if not e.get('교강사 및 담당주차'):note+='담당교수와 담당주차는 해당 원문 행에 미공개입니다. '
    note+='원문 비고: '+notes+'; 일반기간9/1~12/7, 중간시험10/20~26 보수적예약보류, 자체휴일 제외, 공식보강은 원교시·기존방·변경요일 유지.'
    x['remarks']=note;x['departmentRemarks']={k:note for k in x['departmentRemarks']}
    x['reservationProof']={'kind':'directPublishedReservationWindow','actualAttendanceConfirmed':False,'actualInstructionMinutesConfirmed':False,'restMayBeIncluded':True,'modeOverrideApplied':False,'sourceRows':[{'sheet':r['sheet'],'row':r['row']} for r in source],'professorPublished':bool(e.get('교강사 및 담당주차'))}
    expanded.append({'sourceId':x['sourceId'],'courseCode':x['courseCode'],'section':x['section'],'courseName':x['courseName'],'blocks':blocks,'datedReservations':len(plans),'professorPublished':bool(e.get('교강사 및 담당주차'))})
  new.append(x)
assert len(new)==80 and len({c['sourceId'] for c in new})==80
assert len(expanded)==14,len(expanded)
unchanged=0
for old,x in zip(original,new):
 if old['sourceId'] not in {e['sourceId'] for e in expanded}:assert old==x;unchanged+=1
 else:
  for k,v in old.items():
   if k not in {'schedules','scheduleStatus','nativePeriodBlocks','remarks','departmentRemarks'}:assert x[k]==v,(old['sourceId'],k)
assert unchanged==66
for campus,name in [('seunghak','승학캠퍼스'),('unknown','캠퍼스 미확인·외부대학 운영')]:
 out={'schemaVersion':2,'universityId':'donga','campus':campus,'campusName':name,'academicYear':2026,'semester':'2','publishedDate':'2026-09-03','sourceUrl':'https://wwwnew.donga.ac.kr/article/bbs-62/8464209?from=%2Fcommunity%2Facademic-notices','researchOnly':True,'completionClaim':False,'wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'courses':[c for c in new if c['campus']==campus]}
 (OUT/f'donga-{campus}-2026-2.ordinary-reservation-v3.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
audit={'researchOnly':True,'completionClaim':False,'wholeSchoolCourseCoverageComplete':False,'sourceQueryPagesObserved':False,'inputSources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in INPUTS},'nativeObjects':80,'scheduledObjects':sum(bool(c['schedules']) for c in new),'datedReservations':sum(len(c['schedules']) for c in new),'heldObjects':sum(not c['schedules'] for c in new),'expandedObjects':expanded,'originalScheduled11ExactPreserved':True,'other66ObjectsDeepEqual':True,'theorySingleDayMandatory75MinuteConflictHeld':sorted(conflictingTheory),'allNativeEducationalFieldsPreserved':True,'actualModelVerification':'pending SDK slot','noProductOrSDKUse':True}
(OUT/'candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k in ['nativeObjects','scheduledObjects','datedReservations','heldObjects']})
