"""Hold one explicitly intensive bootcamp course; preserve education and student condition."""
import pathlib,json,copy,hashlib
R=pathlib.Path(__file__).resolve().parent;files=[];changes=[]
for campus in ['anseong','pyeongtaek']:
 old=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r9.json').read_text());d=copy.deepcopy(old)
 for c in d['courses']:
  if c['departments'][0]=='전자공학전공' and c['courseCode']=='2002430019' and c['section']=='B01':
   assert len(c['schedules'])==15
   c['schedules']=[];c['scheduleStatus']='unrecognized';c['metadata']['currentExplicitIntensiveOperatingException']={'sourceUrl':'https://counsel.hknu.ac.kr/bbs/ee/287/97172/artclView.do','publishedDate':'2026-07-10','educationalPdfUrl':'https://counsel.hknu.ac.kr/bbs/ee/287/113422/download.do','educationOnlyPages':[1,50],'firstEducationalPageExplicitCondition':'반도체종합공정공학(부트캠프 몰입형 교과목-잔여학점 인정)','currentActualTimetableCellCondition':'부트캠프-몰입형','actualIntensiveDatesUnpublished':True,'nativeCodeAndSectionFromOriginalJuly14Publication':'2002430019-B01','noStudentAssignmentPagesStored':True,'sourceNativeClassificationAndCreditRecognitionDistinguished':True}
   c['departmentRemarks'][c['departments'][0]]+='\n전자공학 공식 현재 운영예외: 반도체종합공정공학은 부트캠프 몰입형 교과목. 실제 집중 운영기간·회의 날짜 미게시이므로 정규 월간 반복회의 생성 보류. 원 등록 이수구분과 별도로 현재 학점인정은 전공선택이 아닌 잔여학점으로 공지됨.'
   changes.append(c['sourceId'])
 for a,b in zip(old['courses'],d['courses']):
  if a['sourceId'] not in changes:assert a==b
  for k in ['sourceId','courseCode','section','departments','departmentClassifications','departmentCredits','professor','sourceSchedule','sourceClassroom']:assert a[k]==b[k]
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r10.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
assert len(changes)==1
m=json.loads((R/'hknu-planned-audited-20261008-r9-sha-manifest.json').read_text());m['files']=files;m['totalScheduledCount']=sum(x['scheduledCount'] for x in files);m['totalDateCount']=sum(x['dateCount'] for x in files);m['currentExplicitIntensiveCourseHeld']=changes;m['allOtherObjectsByteEquivalentToR9']=True
(R/'hknu-planned-audited-20261008-r10-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files)
