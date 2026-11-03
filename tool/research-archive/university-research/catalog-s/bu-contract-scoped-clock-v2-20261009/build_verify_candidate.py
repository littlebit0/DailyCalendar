import copy,datetime as dt,hashlib,json,pathlib,re,shutil
p=pathlib.Path(__file__).parent;old=p.parent
load=lambda f:json.loads(f.read_text())
basefile=pathlib.Path('assets/timetable/baekseok-unknown-2026-2.json');base=load(basefile)
assert len(base['courses'])==2571 and sum(bool(x['schedules']) for x in base['courses'])==2 and sum(len(x['schedules']) for x in base['courses'])==26
(p/'baseline2571-current-asset.json').write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
for name in ['bu-current2026-2-contract-clock-evidence.json','bu-current-contract-2026-2-clock-crop.png','bu-current-official-teaching-date-records.json','bu-current-teaching-grid-recheck-20261008.json','bu-current-exact-delta-recheck-20261008.json','bu-current-exact-time-changes.json','bu-current-whole-ordinary-partial-next-audit-20261008.json','2026_2_ear.pdf','2026_2_ear.tables.json','bu-current-actual-teaching-weeks-20260825.pdf','2026_2_juyo.pdf','bu-current-closed-20260828.tables.json']:
 shutil.copyfile(old/name,p/name)
clock=load(p/'bu-current2026-2-contract-clock-evidence.json');clocks={x['period']:(x['startMinute'],x['endMinute']) for x in clock['periods']}
assert clocks=={1:(540,590),2:(600,650),3:(660,710),4:(720,770),5:(780,830),6:(840,890),7:(900,950),8:(960,1010),9:(1020,1070)}
assert not clock['wholeFileRetained']
rawrows=load(old/'bu-all-published-code-rows.json');review=load(old/'bu-current-whole-ordinary-partial-next-20261008.json');grid=load(p/'bu-current-official-teaching-date-records.json')['records'];literal={1:['2026-09-07','2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-10-26','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07','2026-12-14'],2:['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01'],3:['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02'],4:['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-22','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-10']}
for wd,dates in literal.items():assert [x['date'] for x in grid if x['sourceWeekday']==wd and x['date']<='2026-12-14' and x['kind']!='원격수업']==dates
candidate=copy.deepcopy(base);proof=[];rawselected=[];keys=[]
for c in candidate['courses']:
 if c['departments']!=['계약학과']:continue
 before=copy.deepcopy(c);identity=c['courseCode']+c['section'];keys.append(identity)
 assert not before['schedules']
 native=[x for x in rawrows if x['publishedCombinedCode']==identity and x['source']=='2026_2_ear.tables.json'];assert len(native)==1
 raw=native[0];values=raw['values'];assert values[2]==identity and values[3]==c['courseName'] and values[7]==c['professor'] and values[8]==c['sourceSchedule'] and values[9]==c['sourceClassroom'] and float(values[5])==c['credits']
 assert values[1]==c['classification']
 assert c['sourceEducationalMetadata']['departments']==['계약학과']
 heldOriginal=copy.deepcopy(c['departmentRemarks'])
 c['departmentRemarks']=copy.deepcopy(c['sourceEducationalMetadata']['departmentRemarks'])
 assert c['departmentRemarks']['계약학과']==values[10]
 m=re.fullmatch(r'([월화수목금])([1-9](?:,[1-9])*)',c['sourceSchedule']);assert m
 wd='월화수목금'.index(m[1])+1;periods=[int(x) for x in m[2].split(',')]
 assert periods==list(range(min(periods),max(periods)+1)) and all(v in clocks for v in periods)
 plans=[{'date':date,'weekday':dt.date.fromisoformat(date).isoweekday(),'startMinute':clocks[min(periods)][0],'endMinute':clocks[max(periods)][1],'classroom':c['sourceClassroom'],'deliveryMode':'inPerson','sourceWeekday':wd,'sourcePeriodNumbers':periods} for date in literal[wd]]
 assert all(x['weekday']==wd for x in plans)
 prev=next(x for x in review['courses'] if x['courseCode']+x['section']==identity)
 assert len(prev['schedules'])==13
 assert [{k:s[k] for k in ['date','weekday','startMinute','endMinute','classroom','deliveryMode']} for s in plans]==prev['schedules']
 c['schedules']=plans;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-14'}
 c['previousResearchDepartmentRemarks']=heldOriginal
 c['remarks']=values[10]+' / 현재2026-2 계약학과 자체1–9교시 직접시각만 적용. 일반학부에 전파하지 않음. 학교 실제수업일자표의 확인된 일반수업만 예약; 공식영상대체5일·12/15~21기말시험은 개별시각 미확인으로 예약하지 않음. 공개 원강의실/미지정교수 원문 보존, 중앙 변경표는 강의실 변경 제외이므로 개별최종변경·시험운영은 별도확인 필요.'
 c['scopedClockProof']={'sourceURL':clock['officialNotice'],'attachmentURL':clock['actualAttachment'],'scope':clock['directScope'],'wholePrivateIdentifierAttachmentRetained':False,'originalAttachmentSHA256':clock['originalSha256'],'nativeCodeSectionSource':'2026_2_ear.pdf','nativePDFPage':raw['page'],'sourceWeekday':wd,'periodNumbers':periods,'nativeCombinedCode':identity}
 allowed={'departmentRemarks','schedules','scheduleStatus','period'}
 assert all(c[k]==before[k] for k in before if k not in allowed)
 proof.append({'sourceId':c['sourceId'],'nativeCombinedCode':identity,'nativeCourse':raw,'sourceWeekday':wd,'nativePeriods':periods,'literalDates':literal[wd],'literalClockStart':clocks[min(periods)][0],'literalClockEnd':clocks[max(periods)][1],'room':c['sourceClassroom'],'expectedPlans':plans,'currentDeltasEqualPreviousReview':True})
 rawselected.append(raw)
assert len(keys)==20
assert sum(bool(x['schedules']) for x in candidate['courses'])==22
assert sum(len(x['schedules']) for x in candidate['courses'])==286
for before,after in zip(base['courses'],candidate['courses']):
 if before['courseCode']+before['section'] not in keys:assert before==after
# Exact contract codes are absent from the known exact closure set used by prior review.
audit=load(old/'bu-current-normalization-and-real-date-audit.json')
assert not(set(keys)&set(audit['audit']['closedPresent']))
changes=load(p/'bu-current-exact-time-changes.json');changed=[x for x in changes if x['combinedCode'] in keys]
assert not changed
candidate.update({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False})
(p/'baekseok-unknown-2026-2.contract-clock-v2.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(p/'contract20-native-source-rows.json').write_text(json.dumps(rawselected,ensure_ascii=False,indent=2)+'\n')
report={'researchOnly':True,'completionClaim':False,'SDKExecuted':False,'metadata':2571,'scheduled':22,'meetings':286,'newScopedScheduled':20,'newScopedMeetings':260,'prior2Courses26MeetingsWholeExactPreserved':True,'other2551WholeObjectsEqual':True,'nativeSourceFieldsPreserved':True,'departmentScopeOnly':'계약학과','clockPropagationToOtherDepartments':0,'literalDatesBySourceWeekday':literal,'knownExactClosedContractMatches':0,'knownExactScheduleChangesContractMatches':0,'fivePublishedVideoReplacementDatesHeld':[x for x in grid if x['kind']=='원격수업'],'examDatesNotInvented':['2026-12-15','2026-12-21'],'roomFinalChangesVerified':False,'individualAttendanceVerified':False,'privateWholeClockPDFRedownloaded':False,'privateWholeClockPDFCopied':False,'clockCropSHA256':hashlib.sha256((p/'bu-current-contract-2026-2-clock-crop.png').read_bytes()).hexdigest(),'proofByCourse':proof}
(p/'independent-contract-literal-proof.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('2571 metadata,22 scheduled/286 meetings; new20/260; other2551 exact including old2/26; privatePDF0')
