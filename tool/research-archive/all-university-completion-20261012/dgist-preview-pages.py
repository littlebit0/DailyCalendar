from pathlib import Path
import xml.etree.ElementTree as ET,json,concurrent.futures,subprocess,hashlib
P=Path(__file__).parent/'a-sources';root=ET.parse(P/'dgist-2026-preview-index.xml').getroot();base='https://www.dgist.ac.kr/synap/result/BBSMSTR_000000000463/'
def one(pg):
 n=int(pg.findtext('id'));u=base+pg.findtext('path_html');f=P/f'dgist-2026-preview-page{n}.png'
 if not f.exists():subprocess.run(['curl','-sS','-L','--fail','--retry','2','--retry-all-errors','--retry-delay','1','--max-time','15','-A','Mozilla/5.0',u,'-o',str(f)],capture_output=True)
 b=f.read_bytes() if f.exists() else b''
 return {'page':n,'url':u,'file':str(f),'bytes':len(b),'magicValid':b.startswith(b'\x89PNG'),'sha256':hashlib.sha256(b).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:r=list(ex.map(one,root.findall('./pdf_list/pdf')))
(P/'dgist-preview-pages-receipts.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print([(x['page'],x['magicValid']) for x in r])
