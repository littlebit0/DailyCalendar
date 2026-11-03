import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v43-20261009');old=p.parent/'skku-held-own-operation-v34-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v34.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['GBA2006-01'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'GBA2006-01':['09-07','09-14','09-21','09-30','10-07','10-19','11-09','11-16','11-18','11-25','12-07']};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert 'GBA2006' in re.sub(r'\s','',t);assert 'GBA2006-01' in t and 'Fall Semester 2026' in t;assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
  note='자체현재2026Fall GBA2006-01 exact코드-분반/해당current01공개첨부association 및 Mon13:30–14:45/Wed12–13:15가 native와 정확같은 전체PDF8을 읽었습니다. 원문교수 Hyejin Lee와native이혜진은 동일인 영한확인완료라고 주장하지않고 각원문값을보존합니다(이름만으로조인0). 원문교실미인쇄, 현재native33506만유지. Literal offline ordinary 11날짜만 planned대면예약합니다; 원문Aug31은 현재제품검증기간Sep1경계보다앞이므로보수적으로held하며 자체학사표Aug31개강을Sep1로바꾸어기록하지않습니다. Oct14/Dec9시험, online개별/그룹발표4일, prerecorded영상/quiz제출은미확정live/개별시험시각으로강제변환하지않습니다. Oct19는자체표명시ordinary활동이므로공통중간시험주라고원문수업을제외하지않습니다. 전체과제/평가/출결/변동공지조건notesmetadata보존, 실제출석/시험예약주장0, partialCoverage=true.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-09-01','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV43']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownProfessorEnglish':'Hyejin Lee','nativeProfessorKorean':'이혜진','bilingualIdentityConfirmed':False,'primaryJoinExactCodeSectionSemesterHH':True,'ownClassroomPrinted':False,'classroomFromCurrentNativeOnly':True,'uniqueJoinNotTitleOnly':True,'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v43.json',ds[camp])
assert [r['newMeetings'] for r in proof]==[11];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':1,'newMeetings':11,'byCourse':proof,'completionClaim':False});print(proof)
