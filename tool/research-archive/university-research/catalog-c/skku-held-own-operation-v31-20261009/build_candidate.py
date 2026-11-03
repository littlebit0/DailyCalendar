import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v31-20261009');old=p.parent/'skku-held-own-operation-v29-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v29.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['IKS3028-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'IKS3028-01':['10-26','10-28','11-09','11-11','11-16','11-18']};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert key in re.sub(r'\s','',t);assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
  note='원문현재2026년도2학기 IKS3028-01 전체PDF2를 읽었고 허 요 한 공백정규화만으로 native허요한과 동일확인했습니다. 자체10.26~10.28 및11.9~11.18 모두오프라인 운영기간에 원래Mon10:30–11:45/Wed09–10:15 room9B301을 교집합한6예정수업만대면배정합니다. 이6은 원문개별6날짜 literal이 아닌 원문명시기간내native요일에서 파생되며학교ordinal학기주차환산0,실제출석/시험시각확정0. 1주수요일오프라인+온라인 미확정부분,5/6온라인,8시험,15vs16기말문구상충,다른온라인/초반ordinaryMon은원문전체보존하고이번예약보류합니다. 일반월요일정규배정까지확대했다는주장0,partialCoverage=true.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV31']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':[],'plannedDatesDerivedFromNativeSemester':False,'plannedDatesDerivedFromOwnExplicitIntervalsAndNativeWeekdays':True,'explicitOfflineIntervals':['2026-10-26/2026-10-28','2026-11-09/2026-11-18'],'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v31.json',ds[camp])
assert [r['newMeetings'] for r in proof]==[6];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':6,'byCourse':proof,'completionClaim':False});print(proof)
