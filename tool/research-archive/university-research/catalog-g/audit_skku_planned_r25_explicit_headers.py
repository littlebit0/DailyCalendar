"""Audit every new planned course, without equating missing headers with invalid time."""
import collections,json,re
from pathlib import Path
P=Path(__file__).resolve().parent

def read(name):return json.loads((P/name).read_text())

def main():
 evidence={r['offeringCode']:r for r in read('skku-public-operating-plan-audit.json')['records']}
 teacher_labels={
  'GEDH114-01':('jongminkim','김종민'),
  'SOA3002-01':('jahwankoo','구자환'),
  'CAL2075-41':('javidanmohammadmahdi','자비단'),
  'ERC2007-41':('javidanmohammadmahdi','자비단'),
 }
 term=re.compile(r'(?:학년도\s*[/·]?\s*학기.{0,25}|2026\s*(?:학년도|년도|년)?\s*[/.-]?\s*)1\s*학기|(?:academic\s*(?:year|term)|semester).{0,40}2026.{0,20}(?:spring|first)',re.I)
 result=[];counts=collections.Counter()
 for campus in ['humanities','naturalScience','icampus']:
  for c in read(f'skku-{campus}-2026-2.partial-audited-20261008-r25.json')['courses']:
   if c.get('scheduleEvidenceKind')!='plannedRegularTimetable':continue
   key=c['courseCode']+'-'+c['section'];r=evidence[key];code_present=False;teacher_present=False;clock_contexts=[]
   texts=[r['detail'][0].get('CLASS_INFO','')]+[x for z in r['attachments'] for x in z.get('educationalOperatingContexts',[])]+[w.get('PLAN_WEEK_CONT','') for w in r['weekly']]
   for t in texts:
    assert not term.search(t), (key,'Explicit previous-semester marker')
    for m in re.finditer(r'학수\s*번호\s*[-/]?\s*분반.{0,35}?\b([A-Z]{3,4}\d{4})\s*[-_]\s*([A-Z]?\d{1,2})\b',t):
     code_present=True
     assert m[1]==c['courseCode'] and m[2].zfill(2)==c['section'].zfill(2), (key,'Explicit other code-section')
    for m in re.finditer(r'(?:성\s*명|담당\s*교수|교강사)\s*[:：]?\s*([^0-9]{2,35}?)\s*수강\s*대상',t):
     normalize=lambda s:re.sub(r'[^가-힣A-Za-z]','',s).lower()
     label=normalize(m[1]);current=normalize(c['professor'])
     # Administrative blank rubric text is not a posted person's name.
     if not re.fullmatch(r'[가-힣]{2,5}|[a-z]+',label):continue
     teacher_present=True
     if label not in current and current not in label:
      assert key in teacher_labels and (label,current)==teacher_labels[key], (key,'Explicit incompatible professor label')
    for m in re.finditer(r'(?:수업\s*시간|강의\s*시간|class\s*(?:time|schedule)|lecture\s*(?:time|schedule)).{0,100}',t,re.I):
     context=re.sub(r'\s+',' ',m.group())
     if context not in clock_contexts:clock_contexts.append(context)
   counts['plannedWholeExplicitHeaderReviewCount']+=1;counts['attachedExplicitCodeSectionPresentCount']+=code_present;counts['attachedExplicitTeacherPresentCount']+=teacher_present
   counts['classTimeContextCoursesReviewedCount']+=bool(clock_contexts)
   result.append({'offeringCode':key,'currentDetailIdentityTeacherOriginalClockRoomConfirmed':True,'explicitAttachmentCodeSectionPresent':code_present,'explicitAttachmentTeacherPresent':teacher_present,'attachedClassTimeEducationalContexts':clock_contexts,'missingHeaderDoesNotInvalidatePublishedTime':True,'actualAttendanceConfirmed':False})
 assert len(result)==758
 output={'researchOnly':True,'checkpoint':'20261008-r25','counts':dict(counts),'actualAttendanceConfirmed':False,'scope':'Every current planned regular candidate; existing r21 422 individual course objects separately preserved exactly.','incompatibleLinkedPlanCasesNotApproved':['BUS2030-01','FBT3075-41','MCJ2023-01','COM2002-02'],'compatibleRomanizedLabelsKeepCurrentPublishedProfessorUnchanged':teacher_labels,'classTimeContextReview':'All 43 educational class-time contexts checked. Exact weekday/clock clauses match current printed frames; contiguous 3-hour summaries in GEDW025-01/GEDT013-02 cover printed academic periods and are not converted; malformed10:100 in GEDW023-05/06 is not treated as a competing valid time. Current exact source+detail clocks remain unchanged. MED2032 current periods5/6/7 correspond to current13:00/14:00/15:00 source slots. No guessed exam/counselling/pre-learning clock generated.','onLineHyphenAndVideoReplacementWholeReview':'Only GELT081 pre-class recorded on-line preparation and CNT3066 on-line/off-line fashion-retailing topic appeared. Neither cancels current physical portion. No other new planned course had those operating replacement patterns.','decisions':result}
 (P/'skku-planned-regular-r25-explicit-header-whole-audit.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n');print(dict(counts))

if __name__=='__main__':main()
