import pathlib,json,sys,hashlib
import pypdfium2 as pdfium
p=pathlib.Path(__file__).parent
sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic
f=p/'ena2028-41-attachment1-full-education.json';d=json.loads(f.read_text());body=SpacedPublic('KO').download(d['sourceURL']);assert hashlib.sha256(body).hexdigest()==d['sha256'];doc=pdfium.PdfDocument(body)
for i in range(len(doc)):
 page=doc[i];bitmap=page.render(scale=1.7);img=bitmap.to_pil();img.save('/tmp/skku-ena2028-v139-page-'+str(i+1)+'.png');img.close();bitmap.close();page.close()
doc.close();body=None
print('rendered',len(d['educationFullText']))
