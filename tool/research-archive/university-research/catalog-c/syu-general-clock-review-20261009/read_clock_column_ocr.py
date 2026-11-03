import sys,io,re,json
from pathlib import Path
from PIL import Image
sys.path.insert(0,str(Path('work/university-research/catalog-c/skku-ordinary-reservation-v6-20261009').resolve()))
from native_vision_education_ocr import recognize
P=Path(__file__).resolve().parent;im=Image.open(P/'current-pt-undergraduate-education-table.jpg')
# Only the already verified educational clock column, never account/contact fields.
crop=im.crop((39,97,92,549)).resize((212,1808));b=io.BytesIO();crop.save(b,format='PNG');o=recognize(b.getvalue())
rows=[r for r in o['observations'] if re.search(r'교시|\d{1,2}:\d{2}',r['text'])]
(P/'current-clock-column-independent-ocr.json').write_text(json.dumps({'sourceImageSHA256':'6e529ff18e66fe114b17bbc2ece6f8f969d235f6ee00d83072f70cfd79030479','educationSourceRectanglePixels':[39,97,92,549],'sourcePhysicalScope':'2026-2 physical therapy undergraduate chart','scale':4,'observations':rows,'rawOCRorImageOutput':False},ensure_ascii=False,indent=2)+'\n');print([r['text'] for r in rows])
