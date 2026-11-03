"""Add runtime schema fields while keeping unknown operating facts held."""
import pathlib,json,collections,hashlib,re
P=pathlib.Path(__file__).parent
IDS={'kentech':'0003139','hansei':'0000201','hyupsung':'0000207','sungkyul':'0000131','sunmoon':'0000129','sangji':'0000119'}
for f in P.glob('*.candidate.json'):
 j=json.loads(f.read_text());u=j['universityId']
 if u=='hansei':continue # Fully finalized by parse_hansei.py using native Guest JSON rows.
 j.update(schemaVersion=2,campusName='본교',institutionId='institution:academyinfo:'+IDS[u])
 for c in j['courses']:
  c['departmentCredits']={d:c['credits'] for d in c['departments']}
  c['period']={'startDate':j['termPeriodEvidence']['start'],'endDate':j['termPeriodEvidence']['endInclusive']}
  r=c['sourceEducation'];c['sourceClassroom']=r[8] if u=='sungkyul' else r[9] if u=='sangji' else ' / '.join(re.findall(r'\(([^()]*)\)',r[9]))
  if u=='sungkyul' and any(k in c['courseName'] for k in ['집중수업','학교밖수업']):
   c['schedules']=[];c['scheduleStatus']='unrecognized';c['holdReason']='Explicit concentrated/off-campus teaching; exact dates not published'
  if any(m['endMinute']>1440 for m in c['schedules']):
   c['schedules']=[];c['scheduleStatus']='unrecognized';c['holdReason']='Published overnight clock exceeds current single-day timetable model'
  c['remarks']=c.get('holdReason','')
 publication=json.loads((P/'candidate-publication-evidence.json').read_text()).get(f.stem,{})
 j.update(publication,observedDate='2026-10-11')
 j['courseScheduleStatusCounts']=dict(collections.Counter(c['scheduleStatus'] for c in j['courses']))
 pattern='sangji-fall-timetable/*.pdf' if u=='sangji' else u+'-'+('spring' if j['semester']=='1' else 'fall')+'-timetable.pdf'
 j['sourceHashes']={doc.name:hashlib.sha256(doc.read_bytes()).hexdigest() for doc in P.glob(pattern)}
 f.write_text(json.dumps(j,ensure_ascii=False,indent=2))
