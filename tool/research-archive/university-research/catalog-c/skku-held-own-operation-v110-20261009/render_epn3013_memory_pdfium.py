import pathlib,json,sys,hashlib,subprocess
p=pathlib.Path(__file__).parent;sys.path.insert(0,str(p.parent.parent/'catalog-g'))
from audit_skku_public_operating_plans import SpacedPublic
old=p.parent/'skku-held-own-operation-v108-20261009';d=json.load(open(old/'epn3013-01-attachment1-full-education.json'));c=SpacedPublic('KO');body=c.download(d['sourceURL']);assert hashlib.sha256(body).hexdigest()==d['sha256'];out=pathlib.Path('/tmp/skku-epn3013-visual110-pdfium');out.mkdir(exist_ok=True);import pypdfium2 as pdfium;doc=pdfium.PdfDocument(body);body=None;
for i in range(len(doc)):
 page=doc[i];image=page.render(scale=2).to_pil();image.save(out/f'page-{i+1}.png');page.close()
doc.close();
receipt={'sourceOnly':True,'SDKExecuted':False,'productChanged':False,'completionClaim':False,'rawPDFSaved':False,'originalRawSHA256Exact':d['sha256'],'temporaryRenderPages':[str(x) for x in sorted(out.glob('*.png'))],'renderer':'installed pdfium','renderExitCode':0,'fullVisualEducationalRead':False};(p/'visual-render-source-proof.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt['temporaryRenderPages'])
