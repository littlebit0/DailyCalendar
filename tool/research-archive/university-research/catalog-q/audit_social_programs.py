"""Extract current published social-service program table, preserving case."""
from pathlib import Path
from pypdf import PdfReader
import json,re
p=Path(__file__).parent
reader=PdfReader(p/'kangwon-gw-current-service-guide.pdf')
programs=[]
for page_no in range(8,14):
 t=reader.pages[page_no].extract_text(extraction_mode='layout') or ''
 matches=list(re.finditer(r'14207025([A-Za-z]\d)',t))
 for i,m in enumerate(matches):
  segment=t[m.end():matches[i+1].start() if i+1<len(matches) else len(t)].strip()
  schedule=re.search(r'([월화수목금토일])\s*(\d{1,2},\d{1,2})(?=\s|$)',segment)
  programs.append({'courseCode':'14207025','section':m[1],'sourcePDFPage':page_no+1,'sourceProgramText':segment,'publishedWeekday':schedule[1] if schedule else None,'publishedPeriods':schedule[2] if schedule else None})
rows=json.loads((p/'kangwon-current-whole-source-rows.json').read_text())
current={r['section']:r for r in rows if r['code']=='14207025' and not r['closed']}
pdf={r['section']:r for r in programs}
result={'sourceURL':'https://suganggw.kangwon.ac.kr/resources/file/notice/sugang_bongsa_20262.pdf','actualProgramRows':len(programs),'distinctProgramRows':len(pdf),'currentActiveCourseRows':len(current),'sourceActivityPeriod':['2026-09-14','2026-12-04'],'plannedNotConfirmedOrientationDates':['2026-09-07','2026-09-09','2026-12-14'],'currentNotInProgramPDF':sorted(set(current)-set(pdf)),'pdfNotInCurrent':sorted(set(pdf)-set(current)),'sourceTimeDifferences':[],'programRows':programs,'clockClaim':'Program table supplies period labels; service PDF has 0..12 60minute blocks including rest, general lecture guide separately50minute teaching. Institution actual activity clocks need check before choosing end.'}
for section in set(current)&set(pdf):
 a=current[section]['sourceSchedule'];b=pdf[section]
 if a.replace(' ','')!=str(b['publishedWeekday'])+str(b['publishedPeriods']):
  result['sourceTimeDifferences'].append({'section':section,'currentXLS':a,'pdfDay':b['publishedWeekday'],'pdfPeriods':b['publishedPeriods']})
(p/'kangwon-gw-current-service-program-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('programs',len(programs),'unparsed',sum(r['publishedWeekday'] is None for r in programs),'actualClockDifferences',result['sourceTimeDifferences'])
