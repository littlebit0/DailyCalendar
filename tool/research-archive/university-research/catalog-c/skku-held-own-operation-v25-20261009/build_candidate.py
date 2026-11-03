import json,pathlib,copy,datetime,shutil,re
p=pathlib.Path(__file__).parent;v21b=p.parent/'skku-held-own-operation-v24-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for campus in ['humanities','naturalScience','icampus']:
 f=v21b/f'skku-{campus}-2026-2.own-operation-v24.json'
 if not f.exists():f=v21b/f'baseline-skku-{campus}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{campus}-2026-2.json');bs[campus]=read(f)
ds=copy.deepcopy(bs);keys=['CFTD122-02','CFTD045-01','GEDC010-50'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-three-full-attachment-identities.json',{'sourceOnly':True,'records':list(src.values())});shutil.copyfile(v21b/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'CFTD122-02':['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01'],'CFTD045-01':['08-31','09-07','09-14','09-21','10-12','10-19','10-26','11-02','11-09','11-16','11-23','11-30','12-07'],'GEDC010-50':['09-03','09-10','10-01','10-15','10-29','11-12','11-19','11-26','12-10']}
proof=[]
for campus,dataset in ds.items():
 for c in dataset['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert f['fullEducationalTextRead'];assert '2026' in t;assert key.replace('-','') in re.sub(r'\s|-','',t);assert c['professor'] in t;d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',c['courseCode'],c['section'],c['professor']);assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert not c['schedules']
  plans=[]
  for md in dates[key]:
   day=datetime.date.fromisoformat('2026-'+md);matches=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==day.isoweekday()];assert matches
   plans.extend({**x,'date':day.isoformat(),'deliveryMode':'inPerson' if key=='CFTD122-02' else None} for x in matches)
  note='원문현재2026-2 해당분반 전체교육계획과학교native요일시각·강의실·현재정규학기를확인했습니다.파생예정예약과원문실제날짜를구분하며실제출석/개별시험HH/미확정보강은확정하지않습니다.'
  if key=='CFTD122-02':note+=' 자체세페이지current학기/02/교수/화20–20:50 및매주오프라인공동강의직접명시에따른정규매주예정수업14건입니다.날짜는원문literal이아니라nativeTue+ownAug31–Dec18학기에서파생한계획입니다.공통기말12/14–18과source15·16기말제외파생보수경계로12/8·15예약을제외하며개별시험날짜라고주장하지않습니다.옛출력일2025-09-09는본문대로보존하며개별수업일로해석하지않습니다.'
  if key=='CFTD045-01':note+=' 자체current16주강의·소집단토론·수업시연·매주전회복습계획과현재nativeMon18–19:15/19:30–20:45 정규요일을확인했습니다.source5공부자탄강일/6개천절대체휴일이own9/28·10/5휴일과동일하며그휴일및공통기말12/14–18만제외한13Mon26건의계획예약입니다.날짜는원문literal이아니라현재native정규학기파생입니다.주차를개별실제시험날짜로확정하거나사전영상미기재를대면강제근거로삼지않으며mode사용자선택을따릅니다.'
  if key=='GEDC010-50':note+=' 자체actual날짜표의online4날짜/중간온라인10/22/후학기12/24기말과제/12/17별도숭례체험운영미상은예약보류하고나머지9actual목요일교육날짜만native13–13:50/14–14:50 room36215에연결합니다.단순online미표기만으로대면강제하지않고mode사용자선택을따릅니다.12/24온라인보고서마감원문은보존하되학기기간을연장하거나주간수업으로생성하지않습니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV25']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key] if key=='GEDC010-50' else [],'plannedDatesDerivedFromNativeSemester':key!='GEDC010-50','calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'assessmentOrOnlineUnknownDatesHeld':True}
  proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans),'exactPlanDates':dates[key],'sourceDatesAreLiteral':key=='GEDC010-50'})
for campus in ds:
 for old,new in zip(bs[campus]['courses'],ds[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in keys:assert old==new
 ds[campus]['completionClaim']=False
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[campus]['courses']):write(f'skku-{campus}-2026-2.own-operation-v25.json',ds[campus])
assert sorted(x['newMeetings'] for x in proof)==[14,18,26]
write('new-three-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':3,'newMeetings':58});print(proof)
