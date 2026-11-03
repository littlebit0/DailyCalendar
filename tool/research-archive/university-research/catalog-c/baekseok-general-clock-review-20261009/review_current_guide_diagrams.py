import sys,io,re,json,hashlib
from pathlib import Path
import pypdfium2
sys.path.insert(0,str(Path('work/university-research/catalog-c/skku-ordinary-reservation-v6-20261009').resolve()))
from native_vision_education_ocr import recognize
source=Path('work/university-research/catalog-s/2026_2_juyo.pdf')
body=source.read_bytes();doc=pypdfium2.PdfDocument(body)
records=[]
for n in range(27,36):
 im=doc[n].render(scale=2.5).to_pil();out=io.BytesIO();im.save(out,format='PNG')
 o=recognize(out.getvalue())
 kept=[]
 for row in o['observations']:
  t=row['text']
  if re.search(r'전화|연락|e-?mail|TEL|암호|비밀번호|학번|로그인|아이디',t,re.I):continue
  # Keep isolated published HH tokens only: no whole screenshot or account text.
  times=re.findall(r'(?<![\d:.])(?:[01]?\d|2[0-3]):[0-5]\d(?::[0-5]\d)?(?![\d:.])',t)
  if times:kept.append({'clockTokens':times,'box':row['box'] if 'box' in row else row.get('normalizedBox'),'contextPersisted':False})
 records.append({'physicalPDFPage':n+1,'HHObservations':kept,'observationCount':len(o['observations']),'wholeOCRPersisted':False})
 print(n+1,len(kept),flush=True)
Path(__file__).with_name('current-guide-diagram-clock-token-review.json').write_text(json.dumps({'sourceURL':'https://www.bu.ac.kr/sites/web/files/sugang/2026_2/2026_2_juyo.pdf','sourceSHA256':hashlib.sha256(body).hexdigest(),'records':records,'periodToClockMappingVerified':False,'researchOnly':True},ensure_ascii=False,indent=2)+'\n')
