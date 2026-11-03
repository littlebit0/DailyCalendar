"""Current official header affiliations; preserve native educational classification.

Research only. Table headers are source opening departments, not eligibility claims.
"""
import collections,hashlib,json,re
from pathlib import Path
import pdfplumber
root=Path(__file__).resolve().parent
source=root/'kyonggi-suwon-2026-2.planned-audited-20261008-r5.json'
data=json.loads(source.read_text());headers={};proof=[]
with pdfplumber.open(root/'kyonggi-external2026-2/2026-2_전공.pdf') as pdf:
 for number in sorted({c['metadata']['sourcePage'] for c in data['courses'] if c['metadata']['sourcePDF']=='2026-2_전공.pdf'}):
  text=pdf.pages[number-1].extract_text() or ''
  matches=re.findall(r'^\[\s*(.*?)\s*\]$',text,flags=re.M)
  assert len(matches)==1,(number,matches)
  header=matches[0].strip();headers[number]=header
  proof.append({'page':number,'actualSourceHeader':header,'source':'2026-2_전공.pdf'})
known=0;general=0
for c in data['courses']:
 metadata=c['metadata'];original=c['classification'];note=c['remarks']
 if metadata['sourcePDF']=='2026-2_교양.pdf':
  c['classification']='교양';c['remarks']=note+'\n학교 교양 편성표의 세부 이수 구분: '+original;metadata['nativeClassification']=original;metadata['broadCategoryEvidence']='2026-2_교양.pdf official published general education scope';general+=1
 else:
  header=headers[metadata['sourcePage']]
  # Exact source department/group names only; common, ROTC and numbering headings
  # do not become invented departments. Source scope never asserts exclusive eligibility.
  if re.search(r'(?:학과|학부|전공)(?:\([^)]*\))?$',header) and header not in {'학과공통','학부공통'}:
   c['departments']=[header];c['departmentCredits']={header:c['credits']};c['departmentClassifications']={header:original};c['departmentRemarks']={header:note};metadata['actualOpeningDepartmentFromPageHeader']=header;metadata['departmentAffiliationEvidence']='Current official course-table page header; not an eligibility restriction';metadata['unknownDepartmentNotFabricated']=False;known+=1
metadata={'completionClaim':False,'productionRegistered':False,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'actualSourceOpeningAffiliationCount':known,'explicitGeneralEducationScopeCount':general,'sourceHeaderEvidence':proof,'reviewBoundary':'Other original native classification labels not guessed; opening department does not restrict enrollment.'}
name='kyonggi-suwon-2026-2.source-affiliations-general-scope-r6-next-20261008.json';payload=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();(root/name).write_bytes(payload);metadata['candidateSHA256']=hashlib.sha256(payload).hexdigest();metadata['candidate']=name;(root/'kyonggi-source-affiliations-general-scope-r6-audit-20261008.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n');print({'actualOpeningAffiliations':known,'actualGeneralEducationScope':general,'candidateSHA256':metadata['candidateSHA256']})
