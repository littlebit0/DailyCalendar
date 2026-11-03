"""Lossless fixed native weekly plans; no actual attendance/individual dates claim."""
import pathlib,json,re,copy,hashlib,datetime,collections,shutil
b=pathlib.Path(__file__).parent;root=b.parents[2];out=b/'hanyang-held-native-bulk-v5-20261010';assert not (out/'SHA256.json').exists();out.mkdir(exist_ok=True)
def write(n,d):(out/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
cal=json.load(open(b/'hanyang-native-clock-room-only-v4-20261009/own-calendar-scope.json'));start=datetime.date.fromisoformat(cal['termStartDate']);end=datetime.date.fromisoformat(cal['termEndDate']);holidays=set(cal['conservativelyHeldNationalHolidayDates']);assert (start.isoformat(),end.isoformat())==('2026-09-01','2026-12-21')
write('own-calendar-scope.json',cal);shutil.copyfile(b/'hanyang-ordinary-source-semantic-v2-20261009/current-public-own-operation-calendar-educational-receipts.json',out/'own-calendar-original-education-receipts.json')
clock=re.compile(r'([월화수목금토일])\((\d\d:\d\d)-(\d\d:\d\d)\)');weekdays={x:i+1 for i,x in enumerate('월화수목금토일')};rows=[];changed=[];datasets={};baseline={};counters=collections.Counter()
for campus in ['seoul','erica']:
 file=root/'assets/timetable'/f'hanyang-{campus}-2026-2.json';d=json.load(open(file));baseline[campus]=copy.deepcopy(d);shutil.copyfile(file,out/f'hanyang-{campus}-baseline.json')
 for c in d['courses']:
  if c['schedules']:continue
  metadata=c['metadata'];edu=metadata['originalEducationalRecord'];aliases=edu['officialAliases'];r=aliases[0];times=r.get('suupTimes') or '';slots=clock.findall(times);reasons=[]
  if not slots or clock.sub('',times).replace(',','').strip():reasons.append('nativeHHMissingOrNonWeekly')
  if r.get('suupYear')!='2026' or r.get('suupTerm')!='20' or r.get('suupNo')!=edu['classId'] or r.get('bunbanNo')!=c['section'] or r.get('haksuNo')!=c['courseCode']:reasons.append('nativeIdentityMismatch')
  if r.get('campusNm')!=('서울' if campus=='seoul' else 'ERICA'):reasons.append('nativeCampusMismatch')
  critical=['suupYear','suupTerm','suupNo','bunbanNo','haksuNo','suupTimes','suupRoomNms','teuksuNm','suupUnitCnt','jipjungGanguiYn','suupOprNm','gyogangsaNms']
  if any(a.get(k)!=r.get(k) for a in aliases for k in critical):reasons.append('nativeAliasOperatingFieldsConflict')
  special=r.get('teuksuNm') or ''
  if r.get('suupViewtypeNm') in ['원격','온오프동시','병행'] or re.search(r'SMART|E-러닝|HY-|온라인|원격|집중|온.?오프동시',special,re.I) or r.get('jipjungGanguiYn')=='1':reasons.append('nativeRemoteHybridOrIntensiveAllocationUnresolved')
  if r.get('suupUnitCnt')!=16 or r.get('suupOprNm')!='일반':reasons.append('nativeNonOrdinaryTermOperation')
  if 'medicalOwnCourseOperatingPeriodUnconfirmed' in metadata['reservationProjection']['heldReasons']:reasons.append('medicalSpecificPeriodUnconfirmed')
  if re.search('현장실습|교육실습|교생|인턴십|인턴쉽|사회봉사|봉사활동|개별|자율연구|독립연구',c['courseName']+' '+(r.get('suupMsg') or '')+' '+(r.get('etc') or '')):reasons.append('specificIndividualOrOffsiteOperatingDatesUnconfirmed')
  if '대체학점' in (r.get('suupMsg') or ''):reasons.append('specificCreditReplacementOperatingPlanUnconfirmed')
  if c['sourceSchedule']!=times:reasons.append('nativeRawVsPublishedClockConflict')
  rooms=[x.strip() for x in (c.get('sourceClassroom') or '').split(',')];empty=all(not x or re.search('비지정|미지정',x) for x in rooms)
  if not empty and len(rooms)!=len(slots):reasons.append('printedDifferentClockRoomAllocationUnconfirmed')
  frames=[]
  if not reasons:
   for i,(wd,a,z) in enumerate(slots):
    ah,am=map(int,a.split(':'));zh,zm=map(int,z.split(':'));s=ah*60+am;e=zh*60+zm
    if ah>=24 or zh>=24 or am>=60 or zm>=60 or s>=e:reasons.append('invalidNativeClock');break
    frames.append({'weekday':weekdays[wd],'startMinute':s,'endMinute':e,'classroom':'' if empty else rooms[i]})
  receipt={'sourceId':c['sourceId'],'campus':campus,'nativeEnrollmentNumber':r.get('suupNo'),'courseCode':c['courseCode'],'section':c['section'],'originalEducationRecord':edu,'oldResearchHeldReasons':metadata['reservationProjection']['heldReasons'],'parserHeldReasons':reasons,'sourceNativeWeeklyHH':times,'sourceNativeRoomUnchanged':c['sourceClassroom'],'nativeOrdinary16Weeks':r.get('suupUnitCnt')==16 and r.get('suupOprNm')=='일반','actualAttendanceClaim':False,'literalCourseDateClaim':False,'humanWholeSyllabusReadClaim':False}
  if reasons:receipt['result']='held';counters.update(reasons);rows.append(receipt);continue
  plans=[];day=start
  while day<=end:
   if day.isoformat() not in holidays:
    for frame in frames:
     if frame['weekday']==day.isoweekday():plans.append({'date':day.isoformat(),**frame,'deliveryMode':None})
   day+=datetime.timedelta(days=1)
  assert plans;old=copy.deepcopy(c)
  note='현재 학교공표2026-2 정확 강좌의 고정 주간 요일·HH 및16주 일반운영과 자체9/1–12/21 학기를 사용한 예정 예약입니다. 실험·실습/IC-PBL 명칭만으로 실제주간배정을 무효화하지 않으며, 별도원격·개별현장·집중·의학운영·배분충돌은 적용하지 않았습니다. 날짜는 원문인쇄 개별날짜가 아닌 자체학기와native매주요일에서 파생했으며 실제등교·출석·시험·보강·최신폐강확인 아님입니다. 원문 비지정 교실은 빈값으로 유지, 명시교실은 원문 literal을 그대로 사용하고 건물접두사나 캠퍼스를 발명하지 않았습니다. 모드는 미확정 사용자선택 그대로입니다. 공식학사력에 시험기간이 없으므로 임의 시험주를 잘라내거나 추가하지 않았습니다. 법정공휴일6일만 보수제외/확정 개별휴강 주장0·12/22 보강가능일 예약0. 이전 연구 단계 보류기록은 아래에 역사적 원문으로 유지하며 해당판단을 최신지원불가능 판단으로 사용하지 않습니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',period={'startDate':start.isoformat(),'endDate':end.isoformat()},remarks=note+'\n[이전 연구기록]\n'+old['remarks'],departmentRemarks={k:note+'\n[이전 연구기록]\n'+v for k,v in old['departmentRemarks'].items()})
  metadata['priorResearchReservationProjection']=old['metadata']['reservationProjection'];metadata['priorResearchRemarks']=old['remarks'];metadata['priorResearchDepartmentRemarks']=old['departmentRemarks'];metadata['reservationProjection']={**old['metadata']['reservationProjection'],'eligible':True,'heldReasons':[],'kind':'publishedNativeOrdinaryWeeklyPlannedReservation','oldHeldReasonsPreservedNotSchoolDirectRestrictions':True,'actualAttendanceConfirmed':False,'actualCourseDatesConfirmed':False,'individualExamsOrMakeupAdded':False};metadata['nativeBulkProof']={'sourceOnly':True,'SDKExecuted':False,'productModified':False,'nativeSourceClockUnchanged':times,'nativeSourceRoomUnchanged':old['sourceClassroom'],'framesExactNative':frames,'unspecifiedRoomBlank':empty,'literalSourceDatesPrinted':False,'noLaboratoryNameAloneGate':True,'actualAttendanceConfirmed':False,'commonCalendarSource':'own-calendar-scope.json','allNativeEducationAliasesAndRestrictionsPreserved':True}
  receipt.update(result='eligiblePublishedWeeklyPlannedOnly',framesExactNative=frames,newPlannedMeetingCount=len(plans));rows.append(receipt);changed.append({'sourceId':c['sourceId'],'campus':campus,'courseCode':c['courseCode'],'section':c['section'],'framesExactNative':frames,'expectedSchedulesCalendarDerived':plans})
 datasets[campus]=d;write(f'hanyang-{campus}-2026-2.native-bulk-v5.json',d)
allold=[c for d in baseline.values() for c in d['courses']];allnew=[c for d in datasets.values() for c in d['courses']];ids={c['sourceId'] for c in changed};assert all(c==next(z for z in allnew if z['sourceId']==c['sourceId']) for c in allold if c['sourceId'] not in ids)
counts={'wholeOfferings':len(allnew),'priorScheduledScopes':sum(bool(c['schedules']) for c in allold),'priorMeetings':sum(len(c['schedules']) for c in allold),'newScheduledScopes':len(changed),'newMeetings':sum(len(c['expectedSchedulesCalendarDerived']) for c in changed),'resultScheduledScopes':sum(bool(c['schedules']) for c in allnew),'resultMeetings':sum(len(c['schedules']) for c in allnew),'remainingHeld':sum(not c['schedules'] for c in allnew)}
write('all1470-held-native-processing-queue.json',rows);write('independent-native-calendar-validation.json',{'sourceOnly':True,'SDKExecuted':False,'productModified':False,'allOtherWholeObjectsUnchanged':len(allold)-len(ids),'counts':counts,'byCourse':changed,'humanWholeReadAdded':0,'clockEstimatedOrInvented':False,'originalNativeFieldsPreserved':True,'actualCourseDatesConfirmed':False,'unknownIndividualMakeupGenerated':False});write('processing-progress.json',{'sourceOnly':True,'SDKExecuted':False,'productModified':False,'completionClaim':False,'processedAllPreviouslyHeld':len(rows),'categories':dict(collections.Counter(x['result'] for x in rows)),'unresolvedReasons':dict(counters),'counts':counts,'networkQueries':0,'lastUpdatedAt':datetime.datetime.now().astimezone().isoformat()})
shutil.copyfile(__file__,out/pathlib.Path(__file__).name)
(out/'HANDOFF.md').write_text('# 한양 서울/ERICA native1470 일괄처리 v5\n\n학교 자체 주간요일·HH/16주 일반운영·자체 기간을 사용한 예정 예약만 처리합니다. 기존 연구가 생성한 실제등교미확인·실습이름 보류와 학교 직접 미배정·원격·집중·시간미지정 조건을 분리했습니다. 원문별 실제강의계획 전수인간판독0/네트워크0/SDK제품0/지원완료주장0. 원문교실미지정은 빈값, 서로다른HH-room 배분충돌은 보류, 일반IC-PBL을 사전녹화라고추정하지 않음. 의학/개별현장기간은보류. prior원문allfields/전체기존일정 보존. 학교403/NetFunnel경계 재조회0.\n\n'+json.dumps(counts,ensure_ascii=False)+'\n')
print(json.dumps(counts,ensure_ascii=False))
