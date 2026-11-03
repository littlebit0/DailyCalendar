import json,pathlib,copy,datetime,shutil,re
p=pathlib.Path(__file__).parent;v21b=p.parent/'skku-held-own-operation-v26-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for campus in ['humanities','naturalScience','icampus']:
 f=v21b/f'skku-{campus}-2026-2.own-operation-v26.json'
 if not f.exists():f=v21b/f'baseline-skku-{campus}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{campus}-2026-2.json');bs[campus]=read(f)
ds=copy.deepcopy(bs);keys=['COS3063-01','FTM3097-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'sourceOnly':True,'records':list(src.values())});shutil.copyfile(p.parent/'skku-held-own-operation-v25-20261009'/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'COS3063-01':['09-09','09-16','09-23','09-30','10-07','10-14','10-28','11-04','11-11','11-18','11-25','11-30','12-02','12-07'],'FTM3097-01':['09-01','09-08','09-15','09-22','09-29','10-06','10-13','10-20','10-27','11-03','11-10','11-17','11-24','12-01','12-08']}
proof=[]
for campus,dataset in ds.items():
 for c in dataset['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert f['fullEducationalTextRead'];assert '2026' in t;assert (key.replace('-','') if key!='FTM3097-01' else 'FTM30971') in re.sub(r'\s|-','',t);assert c['professor'] in t;d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',c['courseCode'],c['section'],c['professor']);assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert not c['schedules']
  plans=[]
  for md in dates[key]:
   day=datetime.date.fromisoformat('2026-'+md);matches=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==day.isoweekday()];assert matches
   plans.extend({**x,'date':day.isoformat(),'deliveryMode':'inPerson' if key=='COS3063-01' else None} for x in matches)
  note='원문현재2026-2 해당분반전체교육계획과현재native요일시각/강의실및동일학교학기범위를확인했습니다.실제출석/개별시험시각/미확정보강을확정하지않으며원문모든운영조건을보존합니다.'
  if key=='COS3063-01':note+=' 자체HWP2026/02 exact01 이은호의월요일사전제작/수요일오프라인기본운영및각actual월일을확인했습니다.첫9/2영상·월요일(on)·중간10/21/10/26·기말12/9/12/14·16주빈내용은예약보류하고actual수요일12날짜및명시11/30·12/7(off)월요일2날짜만각nativeHH로연결합니다.원문교육행은수요일에서다음월요일쌍으로이어지므로학교월요일시작주차로재배열하거나임의주차날짜확정하지않습니다.'
  if key=='FTM3097-01':note+=' 자체PDF2026 2학기 FTM3097-1 안기진(학교native01과같은숫자분반1)의연속15주게임워크샵에서수업이론·제작·플레이·시연·팀피드백을확인했습니다.native화18–19:15/19:30–20:45 room61415배정과ownAug31–Dec18학기/공통기말12/14–18제외regular범위로15Tue30예정예약을생성합니다.날짜는원문literal이아니라native정규배정에서파생된계획이며16주교육/시험/외부프로젝트시각을발명하지않습니다.게임워크샵교육맥락만으로대면을강제하지않아mode사용자선택을따릅니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV27']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key] if key=='COS3063-01' else [],'plannedDatesDerivedFromNativeSemester':key!='COS3063-01','calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'assessmentOrOnlineUnknownDatesHeld':True}
  proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans),'exactPlanDates':dates[key],'sourceDatesAreLiteral':key=='COS3063-01'})
for campus in ds:
 for old,new in zip(bs[campus]['courses'],ds[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in keys:assert old==new
 ds[campus]['completionClaim']=False
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[campus]['courses']):write(f'skku-{campus}-2026-2.own-operation-v27.json',ds[campus])
assert sorted(x['newMeetings'] for x in proof)==[14,30]
write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':2,'newMeetings':44});print(proof)
