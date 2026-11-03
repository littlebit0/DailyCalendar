import sys,io,json,importlib.util,hashlib,re
from native_vision_education_ocr import recognize
from pathlib import Path
import pypdfium2
P=Path(__file__).resolve().parent
old=P.parent/'skku-ordinary-reservation-v5-20261008'
spec=importlib.util.spec_from_file_location('v5',old/'recheck_incomplete_operation.py');v5=importlib.util.module_from_spec(spec);spec.loader.exec_module(v5)
code=sys.argv[1]
src=json.loads((P.parent/'skku-ordinary-reservation-v4-20261008/current-flipped-educational-operation-recheck.json').read_text())['records'];row=next(r['sourceRow'] for r in src if r['offeringCode']==code)
base=v5.old.pdf_evidence
def pdf(body,c,s,prof):
 r=base(body,c,s,prof)
 r['sourcePDFSHA256']=hashlib.sha256(body).hexdigest()
 r['wholeAttachmentOrPagePersisted']=False
 return r
v5.old.pdf_evidence=pdf
record=v5.collect(v5.old.SpacedPublic('KO'),row)
(P/(code+'-current-education.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print({'offeringCode':code,'currentEducationalRecordSaved':True,'rawImageOutput':False})
