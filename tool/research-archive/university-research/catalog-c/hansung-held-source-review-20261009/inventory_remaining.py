from pathlib import Path
import json,sys,hashlib,collections
P=Path(__file__).resolve().parent;H=P.parent.parent/'catalog-h'
sys.path.insert(0,str(Path('tool/timetable').resolve()))
from import_hansung import schedules,clean
B=H/'hansung-registration-after-pass16.json';baseline=json.loads(B.read_text());neutral=set(json.loads((H/'hansung-reviewed-neutral-operating-lines.json').read_text())['lines'])
# Frozen baseline copy; later comparison never reads current assets.
(P/'hansung-frozen-prior-pass16-1489.json').write_bytes(B.read_bytes())
reasons=collections.Counter();rows=[]
intensive={'GEN0993','GEN1031','P010143','P010167','P017023','T030132','V020036','V070078','V076015','Y030038'}
for c in baseline['courses']:
 if c['schedules'] or c['scheduleStatus']=='unscheduled':continue
 key=c['courseCode']+'-'+c['section'];fp=H/'hansung-current-operating-proofs'/f'{key}.json';p=json.loads(fp.read_text());reason=''
 try:m=schedules(c['sourceSchedule'])
 except ValueError as e:reason=str(e);m=[]
 else:
  if p['status']!='currentVerifiedIdentity':reason='current plan not published'
  elif p.get('educationalParserVersion')!=4:reason='parser4 proof absent'
  elif clean(p['sourceSchedule'])!=c['sourceSchedule']:reason='plan/source schedule conflict'
  elif p['sourceOfflineFlag']!='Y':reason='mixed flag requires actual review'
  elif len(p['weeks'])!=15 or not all(w['topicPublished'] for w in p['weeks']):reason='incomplete actual weekly context'
  elif c['courseCode'] in intensive:reason='known intensive operating scope'
  else:reason='remaining individual source-semantic review'
 lines=p.get('operatingNotes',[])+[s for w in p.get('weeks',[]) for s in w['operatingEvidence']]
 unreviewed=list(dict.fromkeys(s for s in lines if s not in neutral))
 rows.append({'sourceId':c['sourceId'],'key':key,'courseName':c['courseName'],'professor':c['professor'],'sourceSchedule':c['sourceSchedule'],'departments':c['departments'],'preliminaryGate':reason,'proofSHA256':hashlib.sha256(fp.read_bytes()).hexdigest(),'publicSourceResponseSHA256':p.get('sourceResponseSha256'),'sourceOfflineFlag':p.get('sourceOfflineFlag'),'sourceOnlineType':p.get('sourceOnlineType'),'unapprovedOperatingLines':unreviewed,'wholeOperatingNotes':p.get('operatingNotes',[]),'weeks':p.get('weeks',[]),'parsedNativeMeetings':m})
 reasons[reason]+=1
(P/'remaining-held458-inventory.json').write_text(json.dumps({'baselineSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'baselineWhole1489':True,'priorScheduled921':True,'priorReservations13679':True,'knownNeutralLinesExcludedFromReapproval':len(neutral),'held':rows,'preliminaryGates':dict(reasons),'newApprovalClaim':False},ensure_ascii=False,indent=2)+'\n')
sem=[r for r in rows if r['preliminaryGate']=='remaining individual source-semantic review']
print(dict(reasons),'semantic',len(sem),'distinctlines',len({s for r in sem for s in r['unapprovedOperatingLines']}))
for i,r in enumerate(sem[:22]):print(r['key'],r['courseName'],r['sourceSchedule'],r['unapprovedOperatingLines'])
