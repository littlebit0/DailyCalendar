from pathlib import Path
import sys,json,re,hashlib
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P.parent/'skku-ordinary-reservation-v6-20261009'))
from native_vision_education_ocr import recognize
f=P/'latest-nursing-education-table-1.png'
r=recognize(f.read_bytes())
r.update({'educationImageSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'visuallyReviewedEducationOnly':True,'printedTerm':'2026-2','printedRevision':'260901','contactsOrStudentIdentifiersVisuallyObserved':0})
assert not any(re.search(r'@|(?<!\d)0\d{1,2}-\d{3,4}-\d{4}|연락처|학번|TEL|FAX',v['text'],re.I) for v in r['observations'])
(P/'latest-nursing-education-image-ocr.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
print('education OCR observations',len(r['observations']))
