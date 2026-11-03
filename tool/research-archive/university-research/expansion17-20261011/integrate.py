import json,hashlib
from pathlib import Path
root=Path.cwd();p=Path(__file__).parent
files=[*sorted((p/'a').glob('*-2026-2.json')),*sorted((p/'b').glob('*.candidate.json')),*sorted((p/'c').glob('*.candidate.json')),*sorted((p/'kangnam').glob('*.candidate.json'))]
assert files
# Validate every candidate before the first product mutation.
for candidate in files:
 data=json.loads(candidate.read_text())
 assert data.get('courses') and data.get('campusName'),candidate
 assert all('departmentCredits' in c and 'period' in c and c['campus']==data['campus'] for c in data['courses']),candidate
 name=f"{data['universityId']}-{data['campus']}-{data['academicYear']}-{data['semester']}.json"
 assert not (root/'assets/timetable'/name).exists(),name
 periods_seen={(c['period']['startDate'],c['period']['endDate'])for c in data['courses']}
 first=min(x[0]for x in periods_seen);last=max(x[1]for x in periods_seen)
 proof=data.get('periodEvidence',data.get('termPeriodEvidence',{}))
 assert proof.get('start',first)==first and proof.get('end',proof.get('endInclusive',last))==last,(candidate,proof)
catalog=json.loads((root/'assets/timetable/catalog.json').read_text());periods=json.loads((root/'assets/timetable/term-periods.json').read_text());entries=periods['additionalUniversities'];receipt=[]
for f in files:
 d=json.loads(f.read_text());assert 'courses'in d and d['courses'],f
 university=d['universityId'];campus=d['campus'];year=d['academicYear'];semester=d['semester'];name=f'{university}-{campus}-{year}-{semester}.json';target=root/'assets/timetable'/name
 assert not target.exists(),target
 assert all('departmentCredits'in c and 'period'in c and c['campus']==campus for c in d['courses']),f
 assert d.get('campusName'),f
 d['schemaVersion']=2 if any(m.get('date') for c in d['courses'] for m in c['schedules']) else d['schemaVersion']
 d.pop('researchOnly',None);d['completionClaim']=False
 period_set={(c['period']['startDate'],c['period']['endDate'])for c in d['courses']}
 start=min(x[0]for x in period_set);end=max(x[1]for x in period_set)
 evidence=d.get('periodEvidence',d.get('termPeriodEvidence',{}));source=evidence.get('sourceUrl',d.get('periodSourceUrl',d['sourceUrl']))
 assert evidence.get('start',start)==start and evidence.get('end',evidence.get('endInclusive',end))==end,(f,evidence,period_set)
 # Unknown dates/times/locations are not filled here: source processing is authoritative.
 target.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');asset=str(target.relative_to(root));catalog.append(asset)
 entry=next((e for e in entries if e['university']==university),None)
 if entry is None:entry={'university':university,'sourceUrl':source,'checkedAt':'2026-10-12','terms':[]};entries.append(entry)
 term={'year':year,'semester':semester,'start':start,'end':end,'sourceUrl':source,'sourceEvidence':evidence}
 existing=[x for x in entry['terms']if x['year']==year and x['semester']==semester]
 if existing:assert existing[0]['start']==start and existing[0]['end']==end,(f,existing,term)
 else:entry['terms'].append(term)
 receipt.append({'candidate':str(f),'asset':asset,'university':university,'campus':campus,'courses':len(d['courses']),'meetings':sum(len(c['schedules'])for c in d['courses']),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'period':term,'scope':d.get('sourceScope',d.get('coverage',d.get('sourceCoverage','Native published subset; see source handoff for completeness')))})
(root/'assets/timetable/catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n');(root/'assets/timetable/term-periods.json').write_text(json.dumps(periods,ensure_ascii=False,indent=2)+'\n')
(p/'integration-receipt.json').write_text(json.dumps({'assets':receipt,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print('Added',len(receipt),'datasets',sum(x['courses']for x in receipt),'courses')
