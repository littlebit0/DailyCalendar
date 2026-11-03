"""Only add official department student restrictions, keeping source data and dates."""
import json,pathlib,hashlib,copy
R=pathlib.Path(__file__).resolve().parent
files=[];changes=[]
for campus in ['anseong','pyeongtaek']:
 original=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r2.json').read_text());d=copy.deepcopy(original)
 for c in d['courses']:
  dept=c['departments'][0];title=c['courseName']
  if dept=='안전공학전공' and '산업의료원' in title:
   note='안전공학전공 공식 현재 안내: 수강신청 전에 담당 교수님께 문의 후 수강신청.';url='https://www.hknu.ac.kr/bbs/hksystem/243/97127/artclView.do'
  elif dept=='전자공학전공' and '산업의료원' in title:
   note='전자공학전공 공식 현재 안내: 산업의료원Ⅱ는 지도교수님께 선정된 학생만 수강신청 가능.';url='https://counsel.hknu.ac.kr/bbs/ee/287/97172/artclView.do'
  else:continue
  c['departmentRemarks'][dept]+='\n'+note;c['metadata']['currentPublishedStudentCondition']={'sourceUrl':url,'readDate':'2026-10-08','studentCondition':note,'noPrivateContactsRetained':True};changes.append({'sourceId':c['sourceId'],'studentCondition':note,'sourceUrl':url})
 for a,b in zip(original['courses'],d['courses']):
  for key in a:
   if key not in ['departmentRemarks','metadata']:assert a[key]==b[key]
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r3.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
m=json.loads((R/'hknu-planned-audited-20261008-r2-sha-manifest.json').read_text());m['files']=files;m['studentConditionOnlyFollowupChanges']=changes;m['allClocksDatesModesIdentitiesOtherEducationUnchangedFromR2']=True
(R/'hknu-planned-audited-20261008-r3-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files);print('student conditions',len(changes))
