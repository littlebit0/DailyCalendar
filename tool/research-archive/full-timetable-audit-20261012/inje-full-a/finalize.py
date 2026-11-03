from pathlib import Path
import json,re,collections,hashlib
p=Path(__file__).parent
native=json.loads((p/'inje-native-all-public-rows.json').read_text());keys=collections.defaultdict(list)
for r in native:keys[(r['교과목'],r['분반'])].append(r)
reports=[json.loads(f.read_text())for f in (p/'report-fields').glob('*.json')];guard=[]
for r in reports:
 if r.get('error'):continue
 info=r.get('courseInformation',{});issue=[]
 if info.get('교과목번호')!=r['code']:issue.append('native code mismatch')
 if info.get('분반')!=r['section']:issue.append('native section mismatch')
 if info.get('과정')!='학사과정' or info.get('학사시스템코드')!='01':issue.append('undergraduate level mismatch')
 if r.get('title')!='2026학년도 2학기 수업계획서':issue.append('semester/year mismatch')
 if (r['code'],r['section'])not in keys:issue.append('not in current public list')
 if issue:guard.append({'code':r['code'],'section':r['section'],'issues':issue})
expected={(r['교과목'],r['분반'])for r in native if r['reportOnclick']}; got={(r['code'],r['section'])for r in reports}; finished=got==expected
errors=[r for r in reports if r.get('error')]
packet={'final':finished and not guard,'wholeCompletion':False,'school':'inje','academicYear':2026,'semester':'2','level':'undergraduate','sourceUrl':'https://navi.inje.ac.kr/AllUsers/Lecture.aspx','nativeListSha256':hashlib.sha256((p/'navi-query-all.html').read_bytes()).hexdigest(),'publishedRowCount':1838,'nativeUniqueCodeSectionCount':len(keys),'visibleReportCount':len(expected),'collectedReportCount':len(got),'educationalFieldGuardFailures':guard,'reportErrors':errors,'unregisteredNativeCourses':[{'code':k[0],'section':k[1],'sourceRows':[r['sourceRow']for r in rs]}for k,rs in keys.items()if k not in expected],'approvedPdfSupplements':json.loads((p/'inje-approved-pdf-supplements.json').read_text()),'nativeRowsFile':'inje-native-all-public-rows.json','reportFieldsFile':'inje-all-report-fields.json','duplicatesEvidenceFile':'inje-exact-code-section-duplicates.json','missingReportKeys':[{'code':k[0],'section':k[1]}for k in sorted(expected-got)],'timingEvidence':'Original weekday+period and classroom are preserved; HH conversion requires official undergraduate clock, not inferred from graduate/another-campus schedule.','campusEvidence':'No universal campus value assumed. Published campus building names/coordinates are in campus-map-published-buildings.json; explicit Busan medical marker separately present.','existing16Preservation':'Preserve original globalbusiness16; no title-only merging into native catalog.'}
(p/'final-source-packet.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2))
(p/'inje-all-report-fields.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2))
print('final',packet['final'],'records',len(reports),'errors',len(errors),'guards',len(guard),'expected',len(expected))
