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
ocr_tables=[]
def pdf(body,c,s,prof):
 r=base(body,c,s,prof)
 doc=pypdfium2.PdfDocument(body)
 for page_number in range(len(doc)):
  if len(doc) > 1 and page_number < 1:
   continue
  page=doc.get_page(page_number);im=page.render(scale=2.5).to_pil();out=io.BytesIO();im.save(out,format='PNG')
  recognized=recognize(out.getvalue())
  kept=[];suppressed=0
  for observation in recognized['observations']:
   text,masked,lost=v5.filter_education(v5.mask_contact_context(observation['text']))
   if lost or not text or (re.search(r'contact|phone|tel|연락처|전화|office|e-?mail|비밀번호|암호',text,re.I) and not re.search(r'수업|시간|주차|학기|\d{1,2}:\d{2}',text)):
    suppressed+=1;continue
   if not re.search(r'주|수업|오프|온라인|차시|강의|팀|발표|토론|시험|디자인|프로젝트|OT|종강|조편성|학습|피드백|휴강|학수|분반|학기|GEDT|week|class|semester|offline|online|\d',text,re.I):
    suppressed+=1;continue
   kept.append({**observation,'text':text})
  ocr_tables.append({'sourcePDFPage':page_number+1,'sourceImagePDFSHA256':hashlib.sha256(body).hexdigest(),'renderScale':2.5,'engine':recognized['engine'],'languages':recognized['languages'],'educationObservations':kept,'nonEducationalObservationsSuppressedCount':suppressed,'wholeRawPageOrOCRPersisted':False})
  r['onePageImageSHA256']=hashlib.sha256(body).hexdigest();r['wholeAttachmentOrPagePersisted']=False
 return r
v5.old.pdf_evidence=pdf
record=v5.collect(v5.old.SpacedPublic('KO'),row)
(P/(code+'-current-education.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
assert len(ocr_tables)>=1
(P/(code+'-operating-table-education-ocr.json')).write_text(json.dumps({'researchOnly':True,'completionClaim':False,'offeringCode':code,'tables':ocr_tables},ensure_ascii=False,indent=2)+'\n')
print({'offeringCode':code,'educationObservations':sum(len(t['educationObservations']) for t in ocr_tables),'pages':len(ocr_tables),'rawImageOutput':False})
