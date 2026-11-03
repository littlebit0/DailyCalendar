from pathlib import Path
import urllib.request,io,json,hashlib,re
from pypdf import PdfReader
P=Path(__file__).resolve().parent
u='https://www.syu.ac.kr/nursing/wp-admin/admin-ajax.php?action=file_download_id&o_name=2026-2_timetable_2600810-1.pdf&t_id=16249'
b=urllib.request.urlopen(u,timeout=35).read();r=PdfReader(io.BytesIO(b));pages=[];contacts=0
for i,p in enumerate(r.pages):
 t=p.extract_text() or ''
 contacts+=len(re.findall(r'@|(?<!\d)0\d{1,2}-\d{3,4}-\d{4}|학번|연락처|TEL|FAX',t,re.I))
 pages.append({'page':i+1,'educationClockLines':[v for v in t.splitlines() if re.search(r'\d{1,2}:\d{2}|2026|학기|시간표',v) and not re.search(r'@|연락|전화|학번|TEL|FAX',v,re.I)],'imageCount':len(p.images)})
out={'sourceURL':u,'sourceSHA256':hashlib.sha256(b).hexdigest(),'pages':pages,'contactsOrStudentIdentifierHints':contacts,'rawPDFSaved':contacts==0,'sourcePhysicalScope':'Linked from nursing undergraduate timetable menu lastmodified2026.08.10'}
(P/'current-nursing-pdf-scope-clock-scan.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
if contacts==0:(P/'current-nursing-undergraduate-educational-timetable.pdf').write_bytes(b)
print(json.dumps(out,ensure_ascii=False,indent=2))
