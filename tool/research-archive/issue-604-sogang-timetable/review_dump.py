import json,re,collections
A='/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-sogang-tt/assets/timetable/sogang-unknown-2026-2.json'
C='/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-c/'
P=C+'sogang-current-public-plan-education/'
held={x['offering']:x['reasons'] for x in json.load(open(C+'sogang-weekly-reservations-independent-20261008/all673-held-reasons-v1.json'))}
cur={r['subjectCode']+'-'+r['section']:r for r in json.load(open('data/sogang-current-20261023.json'))['records']}
a=json.load(open(A))
pat=re.compile(r'(?P<days>[월화수목금토일](?:,[월화수목금토일])*) (?P<s>\d{2}:\d{2})~(?P<e>\d{2}:\d{2}) \[(?P<room>[^\[\]]+)\]')
modeP=re.compile(r'대면|오프라인|in[- ]person|face[- ]to[- ]face|offline|on[- ]campus',re.I)
exP=re.compile(r'비대면|비동기|녹화|동영상|영상\s*(?:강의|수업)|온라인|원격|zoom|webex|recorded|asynchronous|online|remote|virtual|blended|hybrid|혼합|병행|플립|flipped|격주|집중|intensive|휴강|no\s+class|cancel|보강|make[- ]?up|자율|independent\s+study|견학|field\s*trip|현장|답사|외부|사이버',re.I)
U=[c for c in a['courses'] if c['scheduleStatus']=='unrecognized' or 'publishedExamAppointmentEvidence' in c]
rows=[];cnt=collections.Counter()
for c in U:
  k=c['courseCode']+'-'+c['section'];r=cur[k]
  t=json.load(open(P+k+'.json')).get('educationalText','')
  m=pat.fullmatch(r['meetingText'])
  flags={f:r[f] for f in ['cyber','CU','CI','oddEven'] if r.get(f)}
  modes=[t[max(0,x.start()-60):x.end()+80].replace('\n',' ') for x in modeP.finditer(t)]
  ex=[t[max(0,x.start()-60):x.end()+60].replace('\n',' ') for x in exP.finditer(t) if not re.match('비대면',t[x.start():x.end()]) or True]
  kind='hidden' if 'publishedExamAppointmentEvidence' in c else 'unrec'
  cand = bool(m) and not flags and bool(t) and any(re.search(r'대면|오프라인|in[- ]person|face[- ]to[- ]face|offline',x,re.I) and not re.search(r'비대면',x) for x in modes)
  cnt[(kind,'cand' if cand else 'no')]+=1
  rows.append({'k':k,'kind':kind,'meeting':r['meetingText'],'flags':flags,'reasons':[x['type'] for x in held.get(k,[])],'cand':cand,'head':re.sub(r'\s+',' ',t[:500]),'modes':modes,'ex':ex,'remarks':r['remarks'],'desc':r['description'],'reg':r['registrationRemarks']})
print(cnt)
json.dump(rows,open('data/review-dump.json','w'),ensure_ascii=False,indent=1)
