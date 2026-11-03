import json,pathlib,copy,datetime,shutil,re
p=pathlib.Path(__file__).parent;v21b=p.parent/'skku-held-own-operation-v21b-20261009';read=lambda f:json.loads(f.read_text());write=lambda n,v:(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
bs={}
for campus in ['humanities','naturalScience','icampus']:
 f=v21b/f'skku-{campus}-2026-2.own-operation-v21b.json'
 if not f.exists():f=v21b/f'baseline-skku-{campus}-2026-2.json'
 shutil.copyfile(f,p/f'baseline-skku-{campus}-2026-2.json');bs[campus]=read(f)
ds=copy.deepcopy(bs);keys=['PHR3167-41','BIO3010-41','EEE3059-41'];audit=read(p.parent.parent/'catalog-g/skku-public-operating-plan-audit.json');src={r['offeringCode']:r for r in audit['records'] if r['offeringCode'] in keys};write('source-three-full-attachment-identities.json',{'sourceOnly':True,'records':list(src.values())});shutil.copyfile(v21b/'own-current-term-closure-evidence.json',p/'own-current-term-closure-evidence.json')
dates={'PHR3167-41':['09-03','09-10','09-17','10-01','10-08','10-15','10-29','11-05','11-12','11-19','11-26','12-03','12-10'],'BIO3010-41':['08-31','09-02','09-07','09-09','09-14','09-16','09-21','09-23','12-07','12-09','12-14'],'EEE3059-41':['08-31','09-02','09-07','09-09','09-14','09-16','09-21','09-23','09-30','10-07','10-12','10-14','10-21','10-26','10-28','11-02','11-04','11-09','11-11','11-16','11-18','11-23','11-25','11-30','12-02','12-07','12-09','12-16']}
proof=[]
for campus,dataset in ds.items():
 for c in dataset['courses']:
  key=c['courseCode']+'-'+c['section']
  if key not in keys:continue
  prior=copy.deepcopy(c);r=src[key];f=read(p/(key.lower()+'-full-education.json'));t=f['educationFullText'];assert f['fullEducationalTextRead'];assert '2026' in t;assert key.replace('-','') in re.sub(r'\s|-','',t);assert c['professor'] in t;d=r['detail'][0];assert (d['GAESUL_YEAR'],d['GAESUL_TERM'],d['HAKSU_NO'],d['BUNBAN'],d['PER_NAME'])==('2026','20',c['courseCode'],c['section'],c['professor']);assert r['sourceRow']['GYOSI_NAME']==c['sourceSchedule'];assert not c['schedules']
  plans=[]
  for md in dates[key]:
   day=datetime.date.fromisoformat('2026-'+md);matches=[x for x in c['rawMeetingFrameForReviewOnly'] if x['weekday']==day.isoweekday()];assert matches
   plans.extend({**x,'date':day.isoformat(),'deliveryMode':'inPerson' if key=='BIO3010-41' else None} for x in matches)
  note='원문현재2026-2 해당분반 전체 교육계획의 실제 월일·요일과 학교 native 수업시각/현재강의실만 연결한 부분 예약입니다. 실제출석이나 미확정 시험·외부일정·보강을 주장하지 않습니다. 원문 전체 운영조건을 보존합니다.'
  if key=='PHR3167-41':note+=' 자체16실제목요일에서9/24추석,10/22중간기간,12/17기말기간을제외한13날짜의강의/PBL발표를3개native50분시각으로연결합니다.명시대면문구가없어mode사용자선택을따릅니다.'
  if key=='BIO3010-41':note+=' 자체32실제날짜및온오프라인표에서오프라인일반교육11날짜만연결합니다.9/28학교휴일,9/30중간고사,12/16Quiz평가및온라인수업은미확정예약으로보류합니다.첨부의교실추후공지와현재native31213배정을함께보존하며현재native배정만사용합니다.'
  if key=='EEE3059-41':note+=' 이론/실습자체실제날짜및실습시간내이론지정을확인했습니다.9/9이론후PBL은동일nativeWed예약하나이며중복생성하지않습니다.9/30실습수업시간이론보강한건은포함하되저녁과제발표는HH미상으로보류합니다.9/28휴일원일,10/5온라인보강,10/19중간·12/14기말및보고서마감은별도시험실제시각검증까지보류합니다.12/16실습수업시간최종발표는교육예약으로포함합니다.명시대면문구가없어mode사용자선택을따릅니다.'
  c.update(schedules=plans,scheduleStatus='scheduled',unresolvedReasons=[],researchOnly=False,scheduleEvidenceKind='plannedRegularTimetable',actualAttendanceConfirmed=False,commonClosureDatesApplied=True,partialCoverage=True,period={'startDate':'2026-08-31','endDate':'2026-12-18'},priorHeldUnresolvedReasons=prior['unresolvedReasons'],priorHeldDepartmentRemarks=prior['departmentRemarks']);c['departmentRemarks']={k:note+'\n'+v for k,v in prior['departmentRemarks'].items()};c['reservationEvidenceV22']={'exactCurrentPublicSource':r,'exactFullPublicAttachmentEducation':f,'exactLiteralDates':dates[key],'ordinalProjectionApplied':False,'sourceModeNotRewritten':True,'actualAttendanceConfirmed':False,'assessmentOrOnlineUnknownDatesHeld':True}
  proof.append({'offeringCode':key,'sourceId':c['sourceId'],'newMeetings':len(plans),'exactLiteralDates':dates[key]})
for campus in ds:
 for old,new in zip(bs[campus]['courses'],ds[campus]['courses']):
  if old['courseCode']+'-'+old['section'] not in keys:assert old==new
 ds[campus]['completionClaim']=False
 if any(c['courseCode']+'-'+c['section'] in keys for c in ds[campus]['courses']):write(f'skku-{campus}-2026-2.own-operation-v22.json',ds[campus])
assert sorted(x['newMeetings'] for x in proof)==[11,28,39]
write('new-three-scoped-proof.json',{'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'byCourse':proof,'newCourses':3,'newMeetings':78});print(proof)
