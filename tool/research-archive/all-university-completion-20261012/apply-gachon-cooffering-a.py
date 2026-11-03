# coding: utf-8
import copy, hashlib, json, pathlib, re
ROOT=pathlib.Path(__file__).resolve().parents[2]
WORK=pathlib.Path(__file__).parent
TARGET=ROOT/'assets/timetable/organizations/gachon.json'
PACKET=WORK/'gachon-current-cooffering-sourceid-a.json'
def read(p):return json.loads(p.read_text())
def digest(b):return hashlib.sha256(b).hexdigest()
before=TARGET.read_bytes();data=read(TARGET);packet=read(PACKET)
course_paths=[ROOT/'assets/timetable/gachon-global-2026-2.json',ROOT/'assets/timetable/gachon-medical-2026-2.json']
course_hashes={str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in course_paths}
courses={c['sourceId']:c for p in course_paths for c in read(p)['courses']}
held=[];accepted=[]
for row in packet['entries']:
 c=courses.get(row['sourceId']);reasons=[]
 if c is None:reasons.append('SourceId missing from actual course assets')
 elif c['campus']!=row['campus'] or row['sourceLabel'] not in c['departments']:reasons.append('Campus or exact published opening label mismatch')
 # Only explicit original department components; academic grade suffix is published source notation.
 components=[re.sub(r'[1-6]$','',x.strip()) for x in row['sourceLabel'].split('/')]
 if row['department'] not in components:reasons.append('Current department absent from actual PRINT_DPT components')
 parent=[m for m in data['mappings'] if m.get('college')==row['college'] and m.get('department')==row['department'] and m.get('campus','*') in ['*',row['campus']] and m.get('collegeKnown',True) and m.get('sourceUrl') and m.get('evidence')]
 if not parent:reasons.append('Independently verified exact current department parent missing')
 proof=ROOT/row['hierarchySourceFile'] if row.get('hierarchySourceFile') else None
 if proof is None or not proof.exists():reasons.append('Original independent hierarchy source file missing')
 if reasons:held.append({'entry':row,'reasons':reasons})
 else:accepted.append(row)
owners={o['sourceId']:o for o in data['courseOwners']};added=0;merged=0;unchanged=0
for row in accepted:
 owner=owners.get(row['sourceId'])
 if owner is None:
  owner={'sourceId':row['sourceId'],'units':[]};data['courseOwners'].append(owner);owners[row['sourceId']]=owner
 matches=[u for u in owner['units'] if u.get('college')==row['college'] and u.get('department')==row['department'] and not u.get('group')]
 if len(matches)>1:raise RuntimeError('Pre-existing duplicate semantic owner units: '+row['sourceId'])
 if matches:
  u=matches[0];labels=list(dict.fromkeys([u['sourceLabel'],*u.get('sourceLabels',[])]))
  if row['sourceLabel'] not in labels:
   labels.append(row['sourceLabel']);u['sourceLabels']=labels;merged+=1
  else:unchanged+=1
 else:
  owner['units'].append({'college':row['college'],'department':row['department'],'sourceLabel':row['sourceLabel'],'sourceUrl':row['sourceUrl'],'sourceFile':row['sourceFile'],'evidence':row['evidence'],'hierarchySourceUrl':row['hierarchySourceUrl'],'hierarchySourceFile':row['hierarchySourceFile'],'isOfferingUnit':True,'collegeKnown':True,'affiliationStatus':'verified','campus':row['campus'],'legacyNamesPreserved':row['legacyNamesPreserved']});added+=1
backup=WORK/'backups'/('gachon-organizations-before-cooffering-'+digest(before)[:16]+'.json');backup.parent.mkdir(exist_ok=True);backup.write_bytes(before)
after=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();TARGET.write_bytes(after)
assert all(digest(p.read_bytes())==course_hashes[str(p.relative_to(ROOT))] for p in course_paths),'Course source changed'
receipt={'target':str(TARGET),'backup':str(backup),'beforeSha256':digest(before),'afterSha256':digest(after),'packetSha256':digest(PACKET.read_bytes()),'acceptedRows':len(accepted),'acceptedCourses':len(set(r['sourceId'] for r in accepted)),'addedSemanticUnits':added,'mergedSourceLabels':merged,'alreadyPresent':unchanged,'held':held,'sourceCourseHashesUnchanged':course_hashes,'sdkTestsBuildInstallPerformed':False}
(WORK/'gachon-cooffering-apply-receipt-a.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in receipt.items() if k in ['acceptedRows','acceptedCourses','addedSemanticUnits','mergedSourceLabels','alreadyPresent','held']},ensure_ascii=False))
