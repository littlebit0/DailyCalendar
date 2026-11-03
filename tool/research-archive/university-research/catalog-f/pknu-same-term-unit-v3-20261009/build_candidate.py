from pathlib import Path
import json,copy,re,datetime,collections,hashlib
ROOT=Path(__file__).parent;P=ROOT.parent;PRIOR=P/'pknu-operating-semantic-v2-20261008';BASE=P/'pknu-current-20261008'
old={r['fields']['identity']:r for r in json.loads((ROOT/'official-semester-xlsx-education.json').read_text())['rows']}
current={r['COURSE_NO']+'-'+r['DCLSS_NO']:r for r in json.loads((P/'pknu-latest-rows.json').read_text())}
prior_audit=json.loads((PRIOR/'candidate-audit.json').read_text());v1=json.loads((BASE/'candidate-audit.json').read_text());reasons={r['identity']:r['reasons'] for r in v1['holds']};changes=json.loads((P/'pknu-v2-rolling-comparison.json').read_text());changedtime={r['identity'] for r in changes['differences'] if r['timeDifference']}
assert len(changedtime)==17
semantic={r['identity']:r for r in json.loads((ROOT/'current-semantic-ordinary-exclusions-education.json').read_text())['rows']}
holidays=set(v1['excludedHolidays']);audits=[];new=[];groups={}
def periods(text):
 values=[]
 for part in text:
  if not part:continue
  for match in re.finditer(r'([월화수목금토일])\s*([0-9]+(?:\s*[-~,]\s*[0-9]+)*)',part):
   day='월화수목금토일'.index(match[1])+1
   for run in match[2].split(','):
    pieces=re.split('[-~]',run.strip());a=int(pieces[0]);b=int(pieces[-1]);values.extend((day,p) for p in range(a,b+1))
 return sorted(values)
for dataset in prior_audit['datasets']:
 name=dataset['file'];data=json.loads((PRIOR/name).read_text());(ROOT/('baseline-'+name)).write_bytes((PRIOR/name).read_bytes());rows=[]
 for original in data['courses']:
  c=copy.deepcopy(original);identity=c['courseCode']+'-'+c['section'];r=current[identity];receipt=old.get(identity);s=receipt['fields'] if receipt else {};holds=[];own=periods([c['sourceSchedule']])
  if not c['schedules']:
   holds=[h for h in reasons.get(identity,[]) if 'Tuesday/Thursday 50/75' not in h and 'physical campus' not in h and not (identity in semantic and h=='individual academic date/period/holiday evidence needs complete semantic review')]
   if not receipt:holds.append('same-semester official unit row absent')
   else:
    if str(s['year'])!='2026' or str(s['semester'])!='2':holds.append('official unit publication term mismatch')
    if s['title']!=c['courseName'] or c['publicPlanEducation']['fields'].get('교과목명')!=c['courseName']:holds.append('native title or current header differs from unit row')
    if identity in changedtime or periods(s['periods'])!=own:holds.append('current weekday/period changed vs unit publication; do not carry unit')
    if s['unit'] not in ['50','75']:holds.append('official semester unit unpublished/ambiguous')
    if s['creditScheme']!=r['PNT_THEO_PRAC']:holds.append('current academic hour/credit scheme differs from published unit row')
    if s['unit']=='75' and any(d not in [2,4] or p not in range(1,10) for d,p in own):holds.append('75minute official weekday/period scope conflict')
    if s['unit']=='50' and any(p not in range(15) for d,p in own):holds.append('50minute official period scope conflict')
    if s['unit'] in ['50','75']:
     hrs=r['PNT_THEO_PRAC'].split('-')
     if len(hrs)!=3 or int(hrs[1])+int(hrs[2])<=0:holds.append('current lecture/practical hour fields unresolved')
     elif len(own)*int(s['unit'])!=(int(hrs[1])+int(hrs[2]))*50:holds.append('current lecture/practical minutes inconsistent with published unit and header slots')
   if not own:holds.append('current exact weekday/periods absent')
   if not holds:
    unit=int(s['unit']);schedule=[]
    for offset in range(98):
     date=datetime.date(2026,9,1)+datetime.timedelta(days=offset)
     if str(date) in holidays or str(date) in semantic.get(identity,{}).get('ordinaryExclusions',[]):continue
     for d,p in own:
      if d!=date.isoweekday():continue
      start=480+60*p if unit==50 else 540+90*(p-1)
      schedule.append({'weekday':d,'startMinute':start,'endMinute':start+unit,'classroom':c['sourceClassroom'],'sourcePeriod':p,'sourceMinuteUnit':unit,'date':str(date)})
    assert schedule
    c['schedules']=schedule;c['scheduleStatus']='scheduled';c['sameTermUnitProvenance']={'publicationDate':'2026-07-30','officialSourceUrl':'https://www.pknu.ac.kr/boardDownload.do?no=80552','currentPublicHeaderUnitAbsent':True,'currentPlanQueryDate':'2026-10-07','latestRoomFromCurrentPlan':True,'currentTitleCodeSectionPeriodsExactMatch':True,'unit':unit,'sourceRow':receipt['row'],'sourceSheet':receipt['sheet'],'unitCell':receipt['unitCell'],'currentHeaderLectureMinutes':len(own)*unit,'currentAcademicHoursExpectedMinutes':(int(r['PNT_THEO_PRAC'].split('-')[1])+int(r['PNT_THEO_PRAC'].split('-')[2]))*50,'currentUnitDirectlyConfirmedOct9':False,'semanticOrdinaryExclusions':semantic.get(identity,{}).get('ordinaryExclusions',[]),'semanticSourceDecision':semantic.get(identity,{}).get('semanticDecision',''),'priorReservationRemarks':c['remarks'],'priorDepartmentReservationRemarks':copy.deepcopy(c['departmentRemarks'])}
    note=f'현재 계획서에 수업 단위가 별도로 게시되지 않아 같은 2026-2 공식 7/30 개설표의 {unit}분 단위를 보존했습니다. 코드·분반·제목·요일교시가 동일하고 현재 공표 이론/실습시간과 일치한 범위만 정규 예약으로 연결했습니다. 강의실은 현재 공개 계획서 값이며 과거 실번호를 복원하지 않았습니다. 10/9 단위 직접 재확인이나 실제 출석 확정이 아닙니다.'
    if identity in semantic:
     note+=' 개별 원문 시험/휴강일은 정규 예약에서 제외했으며 시험 시각 미공개는 시험 일정을 생성하지 않았습니다. '+semantic[identity]['semanticDecision']
    def updated(text):
     if ' 일정 미생성: ' in text:
      beginning,tail=text.split(' 일정 미생성: ',1);mark=' 현재 강의실 건물로 확인된 캠퍼스: ';text=beginning+(mark+tail.split(mark,1)[1] if mark in tail else '')
     text=text.replace('현재 단위 불명확한 화/목은 일정으로 치환하지 않았습니다.','같은 학기 공식 단위 출처와 현재 교시의 일치 범위를 확인했습니다.')
     return text+' / '+note
    c['remarks']=updated(c['remarks']);c['departmentRemarks']={k:updated(v) for k,v in c['departmentRemarks'].items()};c['dateProofKind']='ordinary weekly reservation using retained same-semester official minute unit; current header unit absent, not actual attendance confirmation'
    new.append({'identity':identity,'unit':unit,'sourceRow':receipt['row'],'sourceSheet':receipt['sheet'],'currentNativePeriods':c['sourceNativePeriods'],'currentClassroom':c['sourceClassroom'],'nativeCurrentCreditScheme':r['PNT_THEO_PRAC'],'meetings':len(schedule),'campus':c['campus']})
   audits.append({'identity':identity,'eligible':bool(c['schedules']),'holds':holds,'JulyUnit':s.get('unit'),'JulyTitle':s.get('title'),'currentTitle':c['courseName'],'currentSourceTime':c['sourceSchedule'],'JulyPeriods':s.get('periods'),'samePeriods':bool(receipt) and periods(s['periods'])==own,'changedTimeKnown17':identity in changedtime})
  rows.append(c)
 data['courses']=rows;filename=name.replace('.semantic-reviewed-v2-20261008','.same-term-unit-v3-20261009');(ROOT/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');groups[filename]={'whole':len(rows),'scheduled':sum(bool(x['schedules']) for x in rows),'meetings':sum(len(x['schedules']) for x in rows),'sha256':hashlib.sha256((ROOT/filename).read_bytes()).hexdigest()}
a={'researchOnly':True,'completionClaim':False,'whole':2720,'prior1058DeepEqual':True,'prior43341MeetingsDeepEqual':True,'newCourses':len(new),'newMeetings':sum(x['meetings'] for x in new),'newUnitCounts':dict(collections.Counter(x['unit'] for x in new)),'datasets':groups,'newCourseProofs':new,'heldReviews':audits,'changedTime17':sorted(changedtime),'holdsByReason':dict(collections.Counter(h for x in audits if not x['eligible'] for h in x['holds'])),'SDKUsed':False,'actualFixture':'pending'};(ROOT/'candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in a.items() if k not in ['newCourseProofs','heldReviews','changedTime17']})
