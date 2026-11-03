# coding: utf-8
import json,pathlib,copy,hashlib,re,datetime as dt,shutil
R=pathlib.Path.cwd();W=R/'work/university-research';B=W/'catalog-c/gachon-kangwon-knu-kwangwoon-native-held-bulk-v1-20261010';O=W/'catalog-c/gachon-kangwon-knu-kwangwoon-native-held-bulk-v2-20261010';O.mkdir(exist_ok=False)
def read(p):return json.loads(p.read_text())
def save(n,v):(O/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=read(B/'independent-native-whole-clock-date-proof.json');q=read(B/'all-four-school-remaining-held-queue.json');ids={x['sourceId']for x in p['eligibleProofs']};newids={'knu/sangju/2026/2/PEED0516/001','knu/sangju/2026/2/PEED0516/002'};notes=[]
calendar=read(W/'catalog-p/knu-current-2026-calendar-items.json');assert calendar['autumnMakeup'][0]=='2026-12-08';assert '10.21.~10.27.'in str(calendar)
excluded={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}|{str(dt.date(2026,10,i))for i in range(21,28)}
for spec in p['datasets']:
 data=read(B/spec['candidateFile']);previous=copy.deepcopy(data);shutil.copy(B/spec['priorFile'],O/spec['priorFile'])
 for c in data['courses']:
  old=copy.deepcopy(c)
  if c['sourceId']in ids and c['sourceId'].split('/')[0]in ['knu','kwangwoon']:
   literals=['실제 수업시간·적용일자 또는 진행 방식 미확인: 시간표 추가 불가','체육 강좌의 실제 수업 운영·장소 검증 중: 확인 전 자동 반복 추가 불가.'];new={k:'\n'.join(z for z in v.splitlines()if z not in literals)for k,v in c['departmentRemarks'].items()};assert new!=c['departmentRemarks']
   notes.append({'sourceId':c['sourceId'],'previousWholeV1Course':old,'removedExactResearchOnlyLines':literals,'nativeRestrictionChanged':False});c['departmentRemarks']=new;c['nativeBulkReservationEvidence']['previousResearchDepartmentRemarksV1']=old['departmentRemarks']
  if c['sourceId']not in newids:continue
  identity=c['courseCode']+'-'+c['section'];op=W/'catalog-p/knu-current-public-plans'/f'{identity}.json';wp=W/'catalog-p/knu-current-public-weekly-plans'/f'{identity}.json';overview=read(op);weekly=read(wp)
  for f in [op,wp]:p['sourceInputsSHA256'][str(f.relative_to(R))]=sha(f)
  assert overview['crseNo']==identity and overview['estblYear']=='2026'and overview['estblSmstrSctcd']=='CMBS001400002';assert len(weekly)==15 and [x['weekSn']for x in weekly]==[str(i)for i in range(1,16)]
  assert all(x['sbjetCd']==c['courseCode']and x['sbjetDvnno']==c['section']and x['estblYear']=='2026'and x['estblSmstrSctcd']=='CMBS001400002'for x in weekly)
  educational={k:overview.get(k)for k in ['crseNo','estblYear','estblSmstrSctcd','sbjetNm','totalPrfssNm','attlcRefMtterCntns','smmryPrpsCntns','lctreGoalCntns','lssnsMethdMediaCntns','lctrePrdInfo','taskEvltnMethdCntns']}
  optext=' '.join(str(educational[k]or'')for k in ['attlcRefMtterCntns','lssnsMethdMediaCntns','lctrePrdInfo']);assert not re.search(r'집중|동영상|비대면|현장|스키장|방학|별도|배정',optext)
  assert not re.search(r'집중|동영상|비대면|현장|스키장|방학|12월|별도|배정',str(weekly))
  parts=re.findall(r'([월화수목금토일]) (\d{2}):(\d{2}) ~ (\d{2}):(\d{2})',c['sourceSchedule']);assert len(parts)==3 and all(x[0]=='금'for x in parts)
  blocks=[{'weekday':5,'startMinute':int(x[1])*60+int(x[2]),'endMinute':int(x[3])*60+int(x[4]),'classroom':c['sourceClassroom']}for x in parts]
  expected=[dict(b,date=f'2026-{m:02}-{d:02}')for m,d in [(9,4),(9,11),(9,18),(10,2),(10,16),(10,30),(11,6),(11,13),(11,20),(11,27),(12,4)]for b in blocks]
  assert len(expected)==33;period={'startDate':'2026-09-01','endDate':'2026-12-07'}
  evidence={'basis':'currentNativeHHAndWhole15WeekPlan; practicalSubjectAloneNotIndividualConcentratedOperation','priorResearchPeriod':old.get('period'),'priorResearchDepartmentRemarks':old['departmentRemarks'],'sourceExplicitDateRanges':[{'startDate':'2026-09-01','endDate':'2026-12-07'}],'actualAttendanceConfirmed':False,'sourceSnapshotDate':'2026-10-08','commonPeriodBoundaryDerivation':'before own publishedDec8 makeup; no printedcourse finaldayclaim','modeOverride':None}
  c.update(schedules=expected,scheduleStatus='scheduled',period=period,nativeBulkReservationEvidence=evidence,departmentRemarks={k:'\n'.join(z for z in v.splitlines()if z!='실제 수업시간·적용일자 또는 진행 방식 미확인: 시간표 추가 불가')+'\n공개 현재 정규 요일·시각과 15주 학부 계획에 따른 기간 내 계획 예약입니다. 실기 학습 주제만으로 다른 분반의 집중 운영을 차용하지 않습니다. 실제 출석·현장배정·최신 변경은 미확인, 중간시험/보강/기말 범위는 보수적으로 보류합니다.'for k,v in old['departmentRemarks'].items()})
  p['eligibleProofs'].append({'sourceId':c['sourceId'],'school':'knu','campus':c['campus'],'originalWholeCourse':old,'sourcePlanEducationalFields':educational,'wholeCurrentWeeklyEducationalPlan':weekly,'sourceClockBlocks':blocks,'sourceDateRanges':evidence['sourceExplicitDateRanges'],'calendarExcludedDates':sorted(excluded),'period':period,'literalMeetingsIndependentExpected':expected,'otherSectionOperationNotBorrowed':'PEED0516-003 explicitlyDecemberintensive is distinctidentity'})
 for before,after in zip(previous['courses'],data['courses']):
  if before['sourceId']not in newids and not any(x['sourceId']==before['sourceId']for x in notes):assert before==after
  elif before['sourceId']in ids:
   for k in before:
    if k not in ['departmentRemarks','nativeBulkReservationEvidence']:assert before[k]==after[k]
 spec['scheduled']=sum(bool(c['schedules'])for c in data['courses']);spec['meetings']=sum(len(c['schedules'])for c in data['courses']);save(spec['candidateFile'],data)
p['sourceInputsSHA256'][str((B/'SHA256.json').relative_to(R))]=sha(B/'SHA256.json');p['census']['knu'].update(added=5,addedMeetings=105,currentPracticalOperationNotIndividuallyResolved=0);save('independent-native-whole-clock-date-proof.json',p)
q['rows']=[x for x in q['rows']if x['sourceId']not in newids];q['remainingHeldCount']=len(q['rows']);assert len(q['rows'])==1573;save('all-four-school-remaining-held-queue.json',q);save('research-warning-only-annotation-correction.json',{'rows':notes,'wholeV1CoursesRetainedAsArchive':True,'nativeSchoolEducationChanged':False})
s=(W/'catalog-c/gachon-kangwon-knu-kwangwoon-bulk-fixture-derivative-v1b-20261010/four_school_native_preservation_partial_clock_mode_drive_test.dart.txt').read_text().replace(B.name,O.name).replace('hasLength(22)','hasLength(24)').replace('hasLength(1575)','hasLength(1573)').replace('hasLength(13103)','hasLength(13105)').replace('98288','98354').replace('and22 source','and24 source')
(O/'four_school_native_preservation_partial_clock_mode_drive_test.dart.txt').write_text(s)
# Independent daily scan verifies literal hardcodedFriday dates without generatedweekday expansion.
for x in p['eligibleProofs'][-2:]:
 a=dt.date(2026,9,1);z=dt.date(2026,12,7);calc=[]
 while a<=z:
  if a.isoweekday()==5 and str(a)not in excluded:calc.extend(dict(b,date=str(a))for b in x['sourceClockBlocks'])
  a+=dt.timedelta(days=1)
 assert calc==x['literalMeetingsIndependentExpected']
for f,s in p['sourceInputsSHA256'].items():assert sha(R/f)==s
save('independent-pure-source-verification.json',{'pythonWholeAndNativeSHA':True,'literalTwoFriday33DatesEachPass':True,'wholePrior22SchedulesUnchanged':True,'researchOnlyNoteCorrections':12,'actualSdkTestRun':False,'sdkProductAgentWrites':0})
(O/'HANDOFF.md').write_text('''# 네 학교 누적 bulk v2

v1 후보22/327 원본 불변. 이 누적 v2는 전체14,678 native, 기존13,081/97,961 whole +신규24/393 →13,105/98,354, 보류1,573입니다. v1의22개 모든 예약/학교원문 필드는 그대로 보존하며 12개 새 지원 항목에 남았던 exact 연구경고만 제거하고 이전whole/note를 research-warning-only-annotation-correction.json 및 metadata에 보존했습니다. 학교 제한은 제거하지 않았습니다.

추가2개는 경북 상주 PEED0516-001/002 동계스포츠입니다. 두 current header/번호/학기/교수 native 및15주 전체계획이 정확합니다. 유의에는 ‘실기 실습 과목’만 있으며 두 문서의 운영 필드/weekly 전체에 집중·방학·스키장배정·별도시각 예외가 없습니다. 학습 목표의 스키/스노우보드 기술 주제를 실제 별도 집중 운영으로 확대하지 않습니다. 003의 명시12월 집중 조건을 다른 분반에 전파하지 않습니다. 자체native금12–13/13–14/14–15 각slot, 학교개강9/1부터보강12/8전12/7까지 계획예약, mid10/21–27/휴일 보류. 각11금요일×3slot=33회, +2/66. 학기 전체 실제 출석/야외 실사용 장소 확정이 아닙니다. 원문sourceClassroom과기존캠퍼스 그대로. deliveryoverride0.

가천+10/162·경북누적+5/105·광운+9/126·강원+0. 나머지 자세한 source scope는 v1 HANDOFF를 참조하며 그 동결은 변경하지 않습니다. 현재 v2 candidate/proof/queue와 단일 통합 `.dart.txt`만 parent최종검증용입니다. SDK/제품/AGENT/네트워크0. Python whole/원문SHA/독립 literal금요일 계산PASS, actualFlutter/3modeDrive는 아직 실행하지 않았습니다. 전체 지원 완료·불가능 주장0.
''')
shutil.copy('/tmp/daily-four-school-v2.py',O/'prepare_v2_source_candidate.py')
save('SHA256.json',{f.name:sha(f)for f in sorted(O.iterdir())if f.is_file()and f.name!='SHA256.json'});print(sha(O/'SHA256.json'))
