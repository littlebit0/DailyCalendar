import json,re
from pathlib import Path
root=Path('.'); out=root/'work/university-research/resume-20261011/skku'
held={}
for p in [root/'assets/timetable/skku-humanities-2026-2.json',root/'assets/timetable/skku-naturalScience-2026-2.json']:
 for c in json.loads(p.read_text())['courses']:
  if not c.get('schedules'): held[c['courseCode']+'-'+c['section']]=c
cache=root/'work/university-research/catalog-c/skku-public-primary-bulk-v192-20261010'; rows=[];patterns=re.compile(r'(?<!\d)(?:2026[.\-/년 ]+)?(?:0?[1-9]|1[012])\s*[./월-]\s*(?:0?[1-9]|[12]\d|3[01])(?:일)?(?!\d)')
for p in cache.glob('*education-cache.json'):
 d=json.loads(p.read_text());k=d.get('offeringCode');text=d.get('educationFullText','')
 if k not in held:continue
 hits=[{'nativeDateToken':m.group(0),'context':text[max(0,m.start()-120):min(len(text),m.end()+180)]} for m in patterns.finditer(text)]
 if hits:rows.append({'offering':k,'cache':str(p),'hits':hits,'existingCourse':{'nativeSchedule':held[k]['sourceSchedule'],'teachingType':held[k].get('sourceEducationalMetadata',{}).get('SUUP_TYPE_NM'),'sourceConcentratedType':held[k].get('sourceConcentratedType')}})
(out/'explicit-date-token-shortlist.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print('held',len(held),'cached',len(list(cache.glob('*education-cache.json'))),'datehitofferings',len(rows))
for r in rows: print(r['offering'], [(x['nativeDateToken'],x['context'].replace('\n',' ')[:240]) for x in r['hits']][:12])
