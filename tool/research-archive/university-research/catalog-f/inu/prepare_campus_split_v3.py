"""Partition immutable current native source by complete official room-campus evidence."""
from pathlib import Path
from copy import deepcopy
from collections import Counter
import json,hashlib
ROOT=Path(__file__).resolve().parent
prior_path=ROOT/'inu-main-2026-2.whole2437-partial-dated-v2.json'
prior=json.loads(prior_path.read_text())
names={'songdo':'송도캠퍼스','michuhol':'미추홀캠퍼스','multiple':'복수 캠퍼스','unknown':'캠퍼스 미확인'}
buckets={key:[] for key in names}
for original in prior['courses']:
 education=original['sourceEducation']
 campuses=education['publicRoomCampusNames']
 if education['publicRoomCampusMappingComplete'] is not True:
  campus='unknown'
 elif campuses==['송도캠퍼스']:
  campus='songdo'
 elif campuses==['미추홀캠퍼스']:
  campus='michuhol'
 elif len(campuses)>1 and set(campuses)=={'송도캠퍼스','미추홀캠퍼스'}:
  campus='multiple'
 else:
  raise ValueError('Unrecognized complete public campus names')
 course=deepcopy(original);course['campus']=campus
 # Stable sourceId intentionally remains inu/main/2026-2/native ID.
 assert course['sourceId']==original['sourceId']
 assert {k:v for k,v in course.items() if k!='campus'}=={k:v for k,v in original.items() if k!='campus'}
 buckets[campus].append(course)
files=[]
for campus,courses in buckets.items():
 out={k:deepcopy(v) for k,v in prior.items() if k!='courses'}
 out.update({'campus':campus,'campusName':names[campus],'candidateRevision':'whole2437-campus-split-v3','campusScopeBasis':'Complete current public room-code/building/campus join only; multiple and incomplete mapping explicitly separated','courses':courses})
 path=ROOT/f'inu-{campus}-2026-2.whole2437-campus-split-v3.json'
 path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 files.append({'campus':campus,'campusName':names[campus],'file':path.name,'SHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'nativeCourses':len(courses),'scheduledCourses':sum(bool(c['schedules']) for c in courses),'datedSlots':sum(len(c['schedules']) for c in courses)})
all_courses=[c for rows in buckets.values() for c in rows]
assert len(all_courses)==2437
assert len({c['sourceId'] for c in all_courses})==2437
assert sum(len(c['schedules']) for c in all_courses)==51330
lookup={c['sourceId']:c for c in all_courses}
assert all({k:v for k,v in lookup[c['sourceId']].items() if k!='campus'}=={k:v for k,v in c.items() if k!='campus'} for c in prior['courses'])
audit={'priorV2File':prior_path.name,'priorV2SHA256':hashlib.sha256(prior_path.read_bytes()).hexdigest(),'files':files,'nativeCourses':2437,'scheduledCourses':1663,'datedSlots':51330,'uniqueStableSourceIds':2437,'allNativeFieldsAndSchedulesExactlyEqualExceptCampus':True,'completionClaim':False,'defaultCampus':'unknown'}
(ROOT/'inu-current-campus-split-v3-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(audit)
