import pathlib,json,copy,shutil,datetime,re
p=pathlib.Path('work/university-research/catalog-c/skku-held-own-operation-v44-20261009');old=p.parent/'skku-held-own-operation-v43b-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for camp in ['humanities','naturalScience','icampus']:
 f=old/f'skku-{camp}-2026-2.own-operation-v43b.json'
 if not f.exists():f=old/f'baseline-skku-{camp}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json');bs[camp]=read(f)
ds=copy.deepcopy(bs);keys=['GBA2028-01','GBA2028-02','GBA2028-03'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-two-full-attachment-identities.json',{'records':list(src.values()),'sourceOnly':True});shutil.copyfile(old/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={k:['09-02','09-09','09-16','09-23','10-07','10-14','10-28','11-04','11-11','11-18','11-23','11-25','11-30','12-02','12-07'] for k in keys};proof=[]
for d in ds.values():
 for c in d['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert 'GBA2028' in t and 'Fall 2026' in t and ('Section '+c['section']) in t;assert f['fullEducationalTextRead'];assert not c['schedules'];q=r['detail'][0];assert q['GAESUL_YEAR']=='2026' and q['GAESUL_TERM']=='20' and q['BUNBAN']==c['section'];assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];plans=[]
  for md in dates[key]:
   date=datetime.date.fromisoformat('2026-'+md);frames=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==date.isoweekday()];assert frames
   plans.extend({**x,'date':date.isoformat(),'deliveryMode':'inPerson'} for x in frames)
  note='자체현재Fall2026 GBA2028 및인쇄된 Section01/02/03 각Mon/Wed HH와교실9B218을 current학교학부 native각분반과정확독립대조했습니다. 현재그각분반정상공개첨부association 검증결과 같은8쪽PDF이며 전체교육조건을읽었습니다. Native교수조윤아/원문Dr.Yuna Cho는각각보존하고 영한동일인검증완료주장0/이름만조인0. 각요일각분반HH가정확한literal In-person15날짜에만 planned대면수업;주차별Video/빈formatproposal/Studyday/Finalexam/개별팀10~15분시간unknown/추후조건은임의예약0. ProjectConsultations도해당literal In-person수업표범위로만계획하며개별팀실제출석시각확정0. sourceactualAug31video이며원문현재학교Aug31–Dec18범위;중간주Oct14는원문실제ordinary토론이며불필요공통시험컷0. 전체팀평가/출결/재공지/진행조건note와metadata보존,sourcepartialCoverage=true,ordinalcalendar추정0.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV44']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'sourceActualLiteralDates':dates[key],'plannedDatesDerivedFromNativeSemester':False,'sourceSectionPrinted':True,'ownProfessorEnglish':'Dr. Yuna Cho','nativeProfessorKorean':'조윤아','bilingualIdentityConfirmed':False,'primaryJoinExactCodeSectionSemesterHH':True,'ownClassroomPrinted':True,'classroomFromCurrentNativeOnly':False,'uniqueJoinNotTitleOnly':True,'calendarBoundaryNotActualIndividualExamDate':True,'exactPlanDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'allSourceConditionsRead':True};proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans)})
for camp in ds:
 for a,b in zip(bs[camp]['courses'],ds[camp]['courses']):
  if a['courseCode']+'-'+a['section'] not in keys:assert a==b
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[camp]['courses']):write(f'skku-{camp}-2026-2.own-operation-v44.json',ds[camp])
assert [r['newMeetings'] for r in proof]==[15,15,15];write('new-two-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'newCourses':3,'newMeetings':45,'byCourse':proof,'completionClaim':False});print(proof)
