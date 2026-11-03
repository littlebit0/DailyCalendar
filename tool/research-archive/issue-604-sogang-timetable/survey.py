import json,re,collections,sys
A='/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-sogang-tt/assets/timetable/sogang-unknown-2026-2.json'
P='/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-c/sogang-current-public-plan-education/'
a=json.load(open(A))
U=[c for c in a['courses'] if c['scheduleStatus']=='unrecognized' or 'publishedExamAppointmentEvidence' in c]
print(len(U))
modeP=re.compile(r'대면\s*(?:수업|강의)|(?:수업|강의)\s*(?:방식|형태|운영)\s*[:：]?\s*(?:대면|오프라인)|in[- ]person|face[- ]to[- ]face|offline\s+(?:class|lecture)|오프라인\s*(?:수업|강의)',re.I)
cnt=collections.Counter();out=[]
for c in U:
  k=c['courseCode']+'-'+c['section']
  t=json.load(open(P+k+'.json')).get('educationalText','')
  hits=[t[max(0,m.start()-40):m.end()+40].replace('\n',' ') for m in modeP.finditer(t)]
  neg=[m.group(0) for m in re.finditer(r'비대면',t)]
  cnt['hasText' if t else 'noText']+=1
  if hits: cnt['modeHit']+=1
  out.append((k,c['scheduleStatus'],bool(t),hits[:3]))
print(cnt)
for x in out[:60]:
  if x[3]: print(x)
