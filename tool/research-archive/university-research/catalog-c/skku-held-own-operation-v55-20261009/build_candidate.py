import pathlib,json,copy,shutil,datetime
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v55-20261009');p.mkdir(exist_ok=True);old=p.parent/'skku-held-own-operation-v52b-20261009';read=lambda f:json.loads(f.read_text())
def write(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v52.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
for key in ['iks2057-01','his3050-01','gec3202-01']:
 folder='skku-held-own-operation-v53-20261009' if key.startswith('gec') else 'skku-held-own-operation-v54-20261009';shutil.copyfile(p.parent/folder/(key+'-full-education.json'),p/(key+'-full-education.json'))
shutil.copyfile(p.parent/'skku-held-own-operation-v54b-20261009/current-primary-public-locators.json',p/'current-primary-public-locators.json');loc={r['offeringCode']:r for r in read(p/'current-primary-public-locators.json')['records']}
a=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');keys=list(loc);rs={x['offeringCode']:x for x in a['records'] if x['offeringCode'] in keys};write('source-current-attachment-identity.json',{'records':list(rs.values()),'sourceOnly':True});ds=copy.deepcopy(bs);proof=[]
dates={'IKS2057-01':['09-04','09-11','09-18','10-02','10-16','11-06','11-13','11-20','11-27','12-04'],'HIS3050-01':['09-03','09-10','09-17','10-01','10-08','10-15','10-29','11-05','11-12','11-19','11-26','12-03','12-10'],'GEC3202-01':['09-03','09-08','09-10','09-15','09-17','09-22','09-29','10-01','10-06','10-08','10-13','10-15','10-27','10-29','11-03','11-05','11-10','11-12','11-17','11-19','11-24','12-01','12-03','12-10']}
for c in [x for d in ds.values() for x in d['courses']]:
 key=c['courseCode']+'-'+c['section']
 if key not in keys:continue
 prior=copy.deepcopy(c);r=rs[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];l=loc[key];assert f['fullEducationalTextRead'] and not c['schedules'];assert l['currentLocatorBytesEqualFrozenEducation'] and l['downloadedCurrentLocatorRawSHAOnly']==f['sha256'];assert l['currentNativeSameCodeSections']==[key];row=l['actualObservedCurrentFileRows'][0];assert (row['GAESUL_YEAR'],row['GAESUL_TERM'],row['HAKSU_NO'],row['BUNBAN'])==('2026','20',c['courseCode'],c['section']);assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
 for md in dates[key]:
  date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames;plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
 note='학교현재공개 '+key+' 2026/20/코드분반 반환row→관찰된개별planID→첨부ID/sequence/publicURL 직접연결과 actualcurrentlocator rawSHA=전체교육원문SHA를독립검증했습니다. 원문code-section미인쇄 사실보존, 교수/title만조인0. 자체현재학기/교수/요일HH/교실(인쇄된경우만) 교차검증, 원문영한교수alias독립확인주장0/native모든필드보존. literal일반수업날짜만native요일HH로 planned예약하며mode명시강제0/null사용자선택. recorded/star/시험/휴강/개별약속/인쇄되지않은일자는예약0,강좌간clock차용0/전체학기날짜추정0/ordinal추정0. 원문모든교육운영조건과교수/원문학기표지/발표/외국인수강대상/변경조건 metadata보존,sourcepartialCoverage=true/actualattendancefalse. IKSsourceFri12–14:45/9B320 자체인쇄, HISsourceThu09–11:45 자체인쇄·교실nativeonly, GEC HH/교실nativeonly; ownprintedidentity와학교currentlocatoridentity엄격분리.'
 c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV55']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'directSchoolCurrentPrimaryLocatorEvidence':l,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'ownCodePrinted':False,'currentSchoolCodeSectionLocatorConfirmed':True,'bilingualIdentityConfirmed':False,'nativeProfessorUnchanged':prior['professor'],'ownHHPrinted':key!='GEC3202-01','ownClassroomPrinted':key=='IKS2057-01','primaryJoinCurrentReturnedCodeSectionLocatorRawSHA':True,'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True,'heldScopes':'Allrecorded/star,exams,NoClass,unprinted individualtimes remain unreserved','otherSemesterSharingAbsentClaim':False};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'expectedSchedulesLiteral':plans})
write('skku-humanities-2026-2.own-operation-v55.json',ds['humanities'])
# Independent manually stated own literal dates and currentnative frames.
literal={'IKS2057-01':(['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04'],{5:[(720,795),(810,885)]},'9B320'),'HIS3050-01':(['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03','2026-12-10'],{4:[(540,615),(630,705)]},'31606'),'GEC3202-01':(['2026-09-03','2026-09-08','2026-09-10','2026-09-15','2026-09-17','2026-09-22','2026-09-29','2026-10-01','2026-10-06','2026-10-08','2026-10-13','2026-10-15','2026-10-27','2026-10-29','2026-11-03','2026-11-05','2026-11-10','2026-11-12','2026-11-17','2026-11-19','2026-11-24','2026-12-01','2026-12-03','2026-12-10'],{2:[(990,1065)],4:[(900,975)]},'9B118')}
for row in proof:
 dd,frames,room=literal[row['offeringCode']];expected=[]
 for date in dd:
  w=datetime.date.fromisoformat(date).isoweekday();assert w in frames
  for start,end in frames[w]:expected.append({'weekday':w,'startMinute':start,'endMinute':end,'classroom':room,'date':date,'deliveryMode':None})
 assert expected==row['expectedSchedulesLiteral'];row['expectedSchedulesLiteral']=expected
count=meetings=other=0
for camp in bs:
 for x,y in zip(bs[camp]['courses'],ds[camp]['courses']):
  if x['courseCode']+'-'+x['section'] not in keys:assert x==y;other+=1
  if x['schedules']:count+=1;meetings+=len(x['schedules'])
assert (other,count,meetings)==(2779,1800,49434);assert sum(len(x['expectedSchedulesLiteral']) for x in proof)==70
write('independent-literal-date-validation.json',{'sourceOnly':True,'SDKExecuted':False,'byCourse':proof,'priorWholeCourses':1800,'priorMeetings':49434,'unchangedOtherWholeObjects':2779,'newWholeCourses':3,'newMeetings':70,'resultWholeCourses':1803,'resultMeetings':49504,'manualValidationPassed':True,'literalDatesNotOrdinalDerived':True});write('new-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':3,'newMeetings':70,'completionClaim':False,'printedSectionExact':False,'currentSchoolCodeSectionDirectPublicLocatorSHAConfirmed':True,'HHScopeByCourse':'IKS/HISownenvelope;GECnativeonly','classroomOwnPrintedIKSOnly':True});print('PASS3/70=>1803/49504 other2779wholeexact')
