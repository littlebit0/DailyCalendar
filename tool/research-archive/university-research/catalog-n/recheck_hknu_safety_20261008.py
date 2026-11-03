"""Recheck only published educational attachments; do not request separate student list."""
import json,pathlib,urllib.request,hashlib,time
R=pathlib.Path(__file__).resolve().parent
sources=[('hknu-safety2026-2-Jul22.xlsx','https://www.hknu.ac.kr/bbs/hksystem/243/113365/download.do')]
out=[]
for fn,url in sources:
 old=hashlib.sha256((R/fn).read_bytes()).hexdigest()
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as r:
  assert r.status==200;blob=r.read(10000000)
 assert blob.startswith(b'PK'),'Normal XLSX body expected; stop on login/WAF response'
 new=hashlib.sha256(blob).hexdigest();out.append({'sourceUrl':url,'status':200,'readDate':'2026-10-08','bytes':len(blob),'originalFile':fn,'originalSHA256':old,'currentSHA256':new,'unchanged':old==new})
 assert old==new,'Changed publication must be reviewed before preparing candidate'
 time.sleep(.8)
(R/'hknu-current-safety-source-recheck-20261008.json').write_text(json.dumps({'researchOnly':True,'studentListNotRequested':True,'records':out},ensure_ascii=False,indent=2)+'\n');print([(x['originalFile'],x['unchanged']) for x in out])
