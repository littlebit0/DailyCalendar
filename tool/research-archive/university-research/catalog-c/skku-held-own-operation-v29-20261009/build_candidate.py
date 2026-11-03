import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v29-20261009');old=p.parent/'skku-held-own-operation-v28-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v28.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['CHI3038-01','CHI3054-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
mon=['08-31','09-07','09-14','09-21','10-12','10-26','11-02','11-09','11-16','11-23','11-30','12-07'];wed=['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-28','11-04','11-11','11-18','11-25','12-02','12-09'];dates={'CHI3038-01':sorted(mon+wed),'CHI3054-01':sorted(mon+wed)};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert key in re.sub(r'\s','',t);assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':None} for x in frames)
  note='원문현재2026-2 해당분반 전체교육계획과 native 정규요일시각/강의실·동일학교학기 Aug31–Dec18을 확인했습니다. 이 날짜들은 원문 literal 개별날짜가 아니라 정규배정에서 파생한 planned 예약입니다. 자체휴일 Sep28/Oct5 및 공통중간 Oct19–23/기말 Dec14–18을 보수적으로 제외했으며 이 공통경계는 확정개별시험일/시험시각의 증거가 아닙니다. ordinal 주차별 실제날짜 환산,미확정보강/시험 예약0; 실제출석 확정0. 별도 대면 명시가 없어 deliveryMode=null로 사용자선택을 따릅니다. '
  note+=' 자체HWP2026년2학기 exact해당01 김 금 남은 공백정규화로 native김금남과 동일합니다. 연속16주 강의·주제탐구·발표/토론·참여/출결 조건을 전체읽었습니다. 8/16주 시험과 개강 후 평가 조정 가능,개별발표·학습작품 추후 공지를 모두 보존하며 주차를 실제시험일로 환산하거나 평가시각을 발명하지않습니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV29']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':[],'plannedDatesDerivedFromNativeSemester':True,'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v29.json',ds[camp])
assert sorted(r['newMeetings'] for r in proof)==[26,26];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':2,'newMeetings':52,'byCourse':proof,'completionClaim':False});print(proof)
