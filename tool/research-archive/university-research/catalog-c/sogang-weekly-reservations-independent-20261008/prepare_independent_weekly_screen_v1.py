from pathlib import Path
import json,re,collections
R=Path(__file__).resolve().parents[4];C=R/'work/university-research/catalog-c';base=json.loads((C/'sogang-additions-v16-20261008/sogang-unknown-2026-2.one-hundred-sixty-four-reviewed-20261008.json').read_text());raw=json.loads((C/'sogang-2026-2.json').read_text())['records'];rawby={r['subjectCode']+'-'+r['section']:r for r in raw};known={}
for p in C.glob('sogang*/*audit*.json'):
 o=json.loads(p.read_text())
 for x in o.get('reviewedStillHeld',[]):
  if isinstance(x,dict)and x.get('offering')and x['offering']!='SCE2104-01':known[x['offering']]=x.get('reason','')
for k in ['EEE3150-01','HISG104-01','HLU4013-01','HSS3031-01','HSS3025-01']:known[k]='Current v16 source wholeheld sourceweekday/endclock/semester/duration conflict, communicated by source reviewer.'
v16=json.loads((C/'sogang-additions-v16-20261008/additions-audit.json').read_text())
for x in v16['proofs']:known[x['offering']]='Current source reviewer v16 explicit dated plan with individual holds; defer wholeoffering to exactdated v16 candidate instead of genericweekly generation.'
pat=re.compile(r'(?P<days>[월화수목금토일](?:,[월화수목금토일])*) (?P<s>\d{2}:\d{2})~(?P<e>\d{2}:\d{2}) \[(?P<room>[^\[\]]+)\]');result=[]
for c in base['courses']:
 k=c['courseCode']+'-'+c['section'];r=rawby[k];assert all(c['sourceEducationalMetadata'][f]==r[f] for f in ['subjectCode','section','title','meetingText','professor','credit','year','semester']);r=c['sourceEducationalMetadata'];m=pat.fullmatch(r['meetingText']);plan=json.loads((C/'sogang-current-public-plan-education'/f'{k}.json').read_text());text=plan.get('educationalText','');reasons=[]
 if c['schedules']:status='existingDatedPreserved'
 else:
  if k in known:reasons.append({'type':'knownWholeConflict','excerpt':known[k]})
  if m and re.search(r'[,/;]|\bor\b',m['room']):reasons.append({'type':'multipleNativeRoomsUnallocated','excerpt':m['room']})
  if not m:reasons.append({'type':'missingOrComplexActualClockRoom','excerpt':r['meetingText']})
  if any(r.get(a)for a in ['cyber','CU','CI','oddEven']):reasons.append({'type':'specialSourceFlagUnresolved','excerpt':{a:r[a]for a in ['cyber','CU','CI','oddEven']if r.get(a)}})
  operation=r['remarks']+' '+r['description']+' '+r['registrationRemarks']
  hit=re.search(r'녹화|비대면|온라인|집중|별도',operation)
  if hit:reasons.append({'type':'nativeSpecialOperation','excerpt':operation[max(0,hit.start()-35):hit.end()+65]})
  head=text[:1200]
  year=re.search(r'(20\d\d)\s*(?:학년도|년|Fall|Spring|년도)',head,re.I)
  if year and year[1]!='2026':reasons.append({'type':'sourceHeaderYearConflict','excerpt':year[0]})
  if re.search(r'2026[^\n]{0,15}(?:Spring|1\s*학기)|(?:Spring|1\s*학기)[^\n]{0,15}2026',head,re.I):reasons.append({'type':'sourceHeaderSemesterConflict','excerpt':head[:220]})
  sections=re.findall(r'(?<![A-Z0-9])'+re.escape(r['subjectCode'])+r'\s*-\s*(\d{1,2})(?!\d)',head)
  if sections and int(r['section']) not in {int(x)for x in sections}:reasons.append({'type':'sourceHeaderSectionConflict','excerpt':'Printed code-sections '+str(sections)})
  codeblock=re.search(r'(?:Course\s*(?:Number|No\.?|Code)|과목\s*(?:번호|코드))\s*([\s\S]{0,90})',head,re.I)
  if codeblock:
   codes=re.findall(r'\b[A-Z]{2,6}\d{3,4}\b',codeblock[1]);
   if codes and r['subjectCode']not in codes:reasons.append({'type':'sourceHeaderCodeNeedsCrosslistProof','excerpt':codeblock[0]})
  clockblock=re.search(r'(?:Class\s*Time|수업\s*시간|강의\s*시간)\s*([\s\S]{0,170}?)(?=Enrollment|수강대상|담당교수|Instructor|교수|\n\s*Ⅰ|$)',head,re.I)
  if clockblock and m:
   rr=re.findall(r'(?<![A-Z0-9])[A-Z]{1,2}\d{3,4}[A-Z]?(?![A-Z0-9])',clockblock[1])
   if rr and m['room'] not in rr:reasons.append({'type':'sourceHeaderClassroomNeedsReview','excerpt':clockblock[0]})
   clocks=re.findall(r'(?<!\d)(\d{1,2})\s*[:：]\s*(\d{2})\s*[~–−-]\s*(\d{1,2})\s*[:：]\s*(\d{2})',clockblock[1]);native=((int(m['s'][:2])*60+int(m['s'][3:])),(int(m['e'][:2])*60+int(m['e'][3:])))
   pairs={(int(a)*60+int(b),int(d)*60+int(e))for a,b,d,e in clocks}
   # Unambiguous whole header single clock conflict; multi-section headers require explicit pair present.
   if pairs and native not in pairs:reasons.append({'type':'sourceHeaderClockNeedsReview','excerpt':clockblock[0]})
  patterns=[('unallocatedOffsiteOperation',r'견학|field\s*trip|외부\s*실습|기업\s*방문|현장\s*답사'),('explicitNonSynchronousOrMixed',r'비동기|녹화\s*(?:동영상|영상|수업|강의)|(?:recorded|asynchronous)\s+(?:video|lecture|class)|(?:수업|강의)[^\n]{0,25}(?:녹화|비동기)|(?:온라인|비대면)[^\n]{0,20}(?:수업|강의)|(?:수업|강의)[^\n]{0,20}(?:온라인|비대면)|(?:online|remote|Zoom)\s+(?:class|lecture|session)|(?:class|lecture|session)[^\n]{0,20}(?:online|Zoom)|blended|hybrid'),('intensiveOrOddEven',r'집중\s*(?:수업|강의|이수)|(?:intensive|concentrated)\s+(?:course|class|lecture)|격주|홀수\s*주|짝수\s*주'),('unallocatedIndividualNoClass',r'No\s+class|휴강|자율\s*(?:학습|수업)|independent\s+study|no\s+(?:offline|in.person)\s+class')]
  for kind,p in patterns:
   for h in re.finditer(p,text,re.I):
    snippet=text[max(0,h.start()-75):h.end()+120].replace('\n',' ')
    if kind=='unallocatedIndividualNoClass' and re.search(r'추석|Chuseok|공휴일|한글날|대체공휴일|국정|공식 휴강일|학교 지정 휴강일|September 24|9/24|9/25|10/5|10/9|9월 24|10월 5',snippet,re.I):continue
    reasons.append({'type':kind,'excerpt':snippet});break
  status='heldKnownOrUnresolvedException'if reasons else'ordinaryWeeklyReservation'
 result.append({'offering':k,'status':status,'sourceMeetingText':r['meetingText'],'reasons':reasons,'sourcePlanSHA256':plan.get('fileSha256'),'sourcePlanPresent':bool(text)})
print(collections.Counter(x['status']for x in result));print(collections.Counter(z['type']for x in result for z in x['reasons']));Path('/private/tmp/daily-sogang-weekly-screen-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
