from pathlib import Path
import json,re,hashlib
p=Path(__file__).parent
prior=Path('work/university-research/catalog-r/deu/new-account-first-year-timetable-v8-20261009/current-first-year-native-543-education.json');d=json.loads(prior.read_text());native={}
def walk(x):
 if isinstance(x,dict):
  if 'nativeIdentity'in x:native[x['nativeIdentity']]=x
  for v in x.values():walk(v)
 elif isinstance(x,list):
  for v in x:walk(v)
walk(d)
rows=json.loads((p/'postopening-native-rows.json').read_text());closures=[]
for row in rows:
 cells=row['cells'];identity=str(cells[4]or'').strip()
 if not re.fullmatch(r'\d{6}-\d{3}',identity):continue
 closures.append({'identity':identity,'professor':cells[0],'department':cells[1],'year':cells[2],'classification':cells[3],'courseName':cells[5],'remarks':cells[6],'sourceLocator':{'file':row['file'],'sheet':row['sheet'],'row':row['row']}})
pre=json.loads(Path('work/university-research/resume-20261011/deu/closure-rows.json').read_text());preids={}
walkpre=lambda x: None
print('native',len(native),'postclosures',len(closures),'matches',[c['identity']for c in closures if c['identity']in native])
prei=json.loads(Path('work/university-research/resume-20261011/deu/integration-evidence.json').read_text());preclosed=set(prei['matchingClosedIdentities']);postmatched={c['identity']for c in closures if c['identity']in native}
result={'completionClaim':False,'researchOnly':True,'originalNativeSource':str(prior),'originalNativeSha256':hashlib.sha256(prior.read_bytes()).hexdigest(),'originalNativeCount':len(native),'postopeningNoticeUrl':'https://www.deu.ac.kr/www/gra-notice.do?mode=view&articleNo=348405','noticeDate':'2026-09-08','newPostopeningClosureCount':len(closures),'newMatchedIdentities':sorted(postmatched-preclosed),'allMatchedClosureIdentities':sorted(postmatched|preclosed),'retainedNativeCount':len(native)-len(postmatched|preclosed),'retainedAreConfirmedCurrentlyOpen':False,'confirmedClockMappings':0,'confirmedTimetableCandidates':0,'matchedEvidence':[{'closure':c,'native':native[c['identity']]}for c in closures if c['identity']in native],'allPostopeningClosures':closures}
(p/'closure-adjudication.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
