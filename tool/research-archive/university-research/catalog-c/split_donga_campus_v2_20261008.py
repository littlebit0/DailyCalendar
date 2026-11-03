"""Campus assignment only; frozen v1 raw course fields remain unchanged."""
import collections, copy, hashlib, json, pathlib
base=pathlib.Path(__file__).parent/'donga-current-20261008'
out=pathlib.Path(__file__).parent/'donga-campus-v2-20261008'
out.mkdir(exist_ok=True)
source=json.loads((base/'donga-institution-2026-2.published-partial-20261008.json').read_text())
def write(name,data):
 (out/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
parts=collections.defaultdict(list);assignments=[]
for original in source['courses']:
 c=copy.deepcopy(original)
 e=[r['education'] for r in c['publicEducationRows']]
 external=any(str(r.get('교과과정 관련'))=='동서대 교과' or str(r.get('교과목명(국문)')).startswith('(DSU)') for r in e)
 own=c['nativeCampus']=='승학' and not external and all('(승학)' in str(r.get('수업장소')) and not any(x in str(r.get('수업장소')) for x in ['주례','센텀']) for r in e)
 key='seunghak' if own else 'unknown';c['campus']=key;parts[key].append(c)
 assignments.append({'sourceId':c['sourceId'],'campus':key,'nativeCampus':c['nativeCampus'],'sourceOperatingInstitution':'동서대학교' if external else '동아대학교 교과(외부 장소 운영 포함)' ,'proof':'Original 수업장소 explicitly (승학), no external university curriculum' if own else 'External university campus, online/field/mixed location or own physical campus not proved'})
files=[]
for key,courses in parts.items():
 d={k:v for k,v in source.items() if k not in {'courses','campus','campusName'}}
 d.update(campus=key,campusName='승학캠퍼스' if key=='seunghak' else '캠퍼스 미확인·외부대학 운영',courses=courses)
 name=f'donga-{key}-2026-2.published-partial-v2-20261008.json';write(name,d)
 files.append({'file':name,'campus':key,'classes':len(courses),'sha256':hashlib.sha256((out/name).read_bytes()).hexdigest(),'scheduledClasses':sum(bool(c['schedules']) for c in courses),'datedMeetings':sum(len(c['schedules']) for c in courses)})
write('campus-assignment-proof.json',{'priorFile':str(base/'donga-institution-2026-2.published-partial-20261008.json'),'changedExistingCourseFields':['campus'],'assignments':assignments,'externalNativeCampusNotRegisteredAsDongaCampus':True})
a=json.loads((base/'candidate-audit.json').read_text());a.pop('candidate');a['candidates']=files;a['campusOnlySplit']=True;a['sourceIdsChanged']=False;write('candidate-audit.json',a)
print(files)
