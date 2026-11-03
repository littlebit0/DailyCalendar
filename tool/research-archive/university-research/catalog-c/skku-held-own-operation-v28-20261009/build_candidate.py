import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v28-20261009');old=p.parent/'skku-held-own-operation-v27-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v27.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['COS3087-01','COS3131-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
mon=['08-31','09-07','09-14','09-21','10-12','10-26','11-02','11-09','11-16','11-23','11-30','12-07'];wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-28','11-04','11-11','11-18','11-25','12-02','12-09'];dates={'COS3087-01':sorted(mon+wed),'COS3131-01':wed};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert key in re.sub(r'\s','',t);assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
  note='원문현재2026-2 해당분반 전체교육계획과 native 정규요일시각/강의실·동일학교학기 Aug31–Dec18을 확인했습니다. 이 날짜들은 원문 literal 개별날짜가 아니라 정규배정에서 파생한 planned 예약입니다. 자체휴일 Sep28/Oct5 및 공통중간 Oct19–23/기말 Dec14–18을 보수적으로 제외했으며 이 공통경계는 확정개별시험일/시험시각의 증거가 아닙니다. ordinal 주차별 실제날짜 환산,미확정보강/시험 예약0; 실제출석 확정0. 별도 대면 명시가 없어 deliveryMode=null로 사용자선택을 따릅니다. '
  if key=='COS3087-01':note+=' 자체HWP 2026/02 COS3087-01 이창규 연속15주 교수강의·발표·토론을 전체읽었습니다. 발표시간은 인원에 따라 조정 가능하고 중간/기말 과제는 발표이며 임의16주 수업/개별발표시각을 추가하지않습니다.'
  else:note+=' 자체HWP26학년도2학기 COS3131-01 공동교수 김가람·임용균 16주 이론·발표·토론과 출결조건을 전체읽었습니다. 중간시험 당일 휴강·9주차주말 리포트,기말 추후공지,학생별발표를 그대로 보존하며 원문8/16주를 계산해 개별실제시험일로 지정하지않습니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV28']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':[],'plannedDatesDerivedFromNativeSemester':True,'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v28.json',ds[camp])
assert sorted(r['newMeetings'] for r in proof)==[26,28];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':2,'newMeetings':54,'byCourse':proof,'completionClaim':False});print(proof)
