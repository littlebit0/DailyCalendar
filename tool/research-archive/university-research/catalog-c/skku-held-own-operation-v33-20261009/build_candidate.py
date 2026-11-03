import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v33-20261009');old=p.parent/'skku-held-own-operation-v31-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v31.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['BIZ3007-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'BIZ3007-01':['09-02','09-09','09-16','09-23','09-30','10-07','10-14','10-21','10-26','10-28','11-04','11-11','11-18','11-25','12-02','12-09']};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert 'BIZ3007' in re.sub(r'\s','',t);assert c['professor'] in t;assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
  note='원문현재2026Fall/2026년도2학기 BIZ3007 심수옥의 전체PDF9를 읽었습니다. 첨부분반01 미인쇄를 숨기지않으며 current2782native에서 BIZ3007은01한분반뿐이고normal해당01공개첨부association+owncode/prof/Mon12–13:15/Wed13:30–14:45 exact로한강좌에유일결합합니다. 원문교실미인쇄(office33313은수업교실아님); 교실33405는currentnative값만유지합니다. Source기본월온라인/수오프라인 및literalWed15날짜+10/26Mon오프라인 실제표로16planned대면예약만생성. 일반Mon영상·reading/과제·research/termtest제출·불명말기Mon과별도시험/보강held. ProjectFeedback실제표를보존하며팀별actualattendance/개별피드백시간은확정하지않습니다. 학기원문literal표와own기간을사용하며학기ordinalmapping0,실제출석/실제시험HH/미확정보강0,sourcepartialCoverage=true. 전체과제·개별평가·진행조건을notesmetadata그대로보존합니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV33']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':False,'uniqueNativeCurrentSection':'01','ownClassroomPrinted':False,'classroomFromCurrentNativeOnly':True,'uniqueJoinNotTitleOnly':True,'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v33.json',ds[camp])
assert [r['newMeetings'] for r in proof]==[16];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':16,'byCourse':proof,'completionClaim':False});print(proof)
