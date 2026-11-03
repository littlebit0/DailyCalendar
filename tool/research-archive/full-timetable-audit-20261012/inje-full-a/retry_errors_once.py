from pathlib import Path
from lxml import etree
import json,subprocess,hashlib,time
p=Path(__file__).parent;receipts=[]
for f in (p/'report-fields').glob('*.json'):
 old=json.loads(f.read_text())
 if not old.get('error'):continue
 res=subprocess.run(['curl','--max-time','18','-sS',old['sourceUrl']],capture_output=True)
 receipt={'code':old['code'],'section':old['section'],'sourceUrl':old['sourceUrl'],'oldError':old['error'],'oldBodyPrefix':old.get('bodyPrefix'),'retryCount':1,'returncode':res.returncode,'sha256':hashlib.sha256(res.stdout).hexdigest()}
 try:
  r=etree.fromstring(res.stdout);d={'code':old['code'],'section':old['section'],'sourceUrl':old['sourceUrl'],'returncode':res.returncode,'sha256':receipt['sha256'],'title':r.findtext('제목'),'courseInformation':{n.tag:(n.text or '')for n in r.findall('./수업계획서/수업정보/*')},'professorName':r.findtext('./수업계획서/담당교수정보/담당교수명'),'professorDepartment':r.findtext('./수업계획서/담당교수정보/담당교수소속'),'officeParent':r.findtext('./수업계획서/수업지원조교정보/소속')}
  info=d['courseInformation']
  if info.get('교과목번호')!=old['code'] or info.get('분반')!=old['section'] or info.get('과정')!='학사과정' or d['title']!='2026학년도 2학기 수업계획서':raise ValueError('identity/semester/level guard failed')
  d['previousAttempt']=old;f.write_text(json.dumps(d,ensure_ascii=False,indent=2));receipt['resolved']=True
 except Exception as e:receipt.update({'resolved':False,'retryError':str(e),'bodyPrefix':res.stdout[:180].decode(errors='replace')})
 receipts.append(receipt);time.sleep(.3)
(p/'bounded-error-retry-receipt.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2));print('retried',len(receipts),'resolved',sum(r['resolved']for r in receipts))
