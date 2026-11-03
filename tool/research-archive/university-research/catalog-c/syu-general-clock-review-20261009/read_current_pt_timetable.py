import sys,io,re,json,hashlib,urllib.request
from pathlib import Path
from PIL import Image
sys.path.insert(0,str(Path('work/university-research/catalog-c/skku-ordinary-reservation-v6-20261009').resolve()))
from native_vision_education_ocr import recognize
url='https://www.syu.ac.kr/gradpt/wp-admin/admin-ajax.php?action=file_download_id&o_name=2026-2%ED%95%99%EA%B8%B0-%EC%8B%9C%EA%B0%84%ED%91%9C_%EA%B0%95%EC%9D%98%EC%8B%A4_1.jpg&t_id=2659'
with urllib.request.urlopen(url,timeout=40) as r:b=r.read();status=r.status
im=Image.open(io.BytesIO(b));out=io.BytesIO();im.save(out,format='PNG');o=recognize(out.getvalue())
kept=[];suppressed=0
for r in o['observations']:
 t=r['text']
 if re.search(r'@|전화|연락처|문의|TEL|FAX|학번|비밀번호|로그인|(?<!\d)0\d{1,2}[- )]\d{3,4}[- ]\d{4}',t,re.I):suppressed+=1;continue
 kept.append(r)
receipt={'researchOnly':True,'sourceURL':url,'sourceSHA256':hashlib.sha256(b).hexdigest(),'status':status,'dimensions':im.size,'educationObservations':kept,'suppressedCount':suppressed,'rawImageSaved':False,'wholeRawOCRSaved':False}
Path(__file__).with_name('current-pt-undergraduate-timetable-education-ocr.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print({'status':status,'dimensions':im.size,'kept':len(kept),'suppressed':suppressed,'SHA256':receipt['sourceSHA256']})
