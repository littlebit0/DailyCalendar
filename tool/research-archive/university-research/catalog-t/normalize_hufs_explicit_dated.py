"""Review fully dated current plans with clocks inherited from their printed header.

Only a single fixed weekday/time/room is accepted. No timetable dates are
invented from week labels, and no shortened exam clock is guessed.
"""
import copy,json,re
from datetime import date,timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parent
semantic_scope={'__file__':str(ROOT/'gate_hufs_pending_operating_review.py')}
exec((ROOT/'gate_hufs_pending_operating_review.py').read_text().split('decisions=[]')[0],semantic_scope)
NONOPERATING=semantic_scope['nonoperating']

def load(path):return json.loads(path.read_text())
def printed_chunks(text):
 # Prefer explicit brackets and Korean calendar notation over textbook section
 # numbers such as 9.1. Only otherwise fall back to line-leading dates.
 patterns=[
  r'(?:\[|\(|【)(9|10|11|12)[/.](\d{1,2})(?:\]|\)|】)',
  r'(9|10|11|12)\s*월\s*(\d{1,2})\s*일',
  r'(?m)^\s*(?:\[|\(|【)?(9|10|11|12)[/.](\d{1,2})(?!\d)(?:\]|\)|】)?(?=\s|[:：,])',
 ]
 matches=[]
 for pattern in patterns:
  matches=list(re.finditer(pattern,text))
  if matches:break
 if not matches:
  months={'sep':9,'oct':10,'nov':11,'dec':12}
  english=list(re.finditer(r'(?i)\b(Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b',text))
  if english:
   result=[]
   for i,match in enumerate(english):
    day=date(2026,months[match[1][:3].lower()],int(match[2]))
    result.append((day,text if len(english)==1 else text[match.start():english[i+1].start() if i+1<len(english) else len(text)]))
   return result
 result=[]
 for i,match in enumerate(matches):
  try:day=date(2026,int(match[1]),int(match[2]))
  except ValueError:raise ValueError('Invalid printed calendar date') from None
  result.append((day,text if len(matches)==1 else text[match.start():matches[i+1].start() if i+1<len(matches) else len(text)]))
 return result

def normalize_year_first_or_last_dates(document):
 result=copy.deepcopy(document)
 weekly=result['fields']['weekly']
 matches=[m for text in weekly.values() for m in re.finditer(r'(?<!\d)(\d{1,2})/(\d{1,2})/2026\b',text)]
 day_first=any(int(m[1])>12 for m in matches)
 month_first=any(int(m[2])>12 for m in matches)
 if day_first and month_first:raise ValueError('Current plan mixes incompatible printed numeric date formats')
 if matches and not day_first and not month_first:raise ValueError('Current plan numeric day/month convention is ambiguous')
 if matches:
  for key,text in weekly.items():
   def replace(match):
    first,second=int(match[1]),int(match[2])
    day=date(2026,second,first) if day_first else date(2026,first,second)
    return '['+str(day.month)+'/'+str(day.day)+']'
   weekly[key]=re.sub(r'(?<!\d)(\d{1,2})/(\d{1,2})/2026\b',replace,text)
 return result

def normalize(course,document):
 meetings=course['schedules']
 if len(meetings)!=1:raise ValueError('Multiple or absent fixed source meetings require separate review')
 fixed=meetings[0];weekday=fixed['weekday'];fields=document['fields']
 if fields['schedule'].splitlines()[0].strip()!=course['sourceSchedule']:raise ValueError('Current plan header differs from current offering')
 # Read these sources independently. This first candidate accepts only a
 # lecture baseline, not unclassified ongoing remote/hybrid arrangements.
 for line in (fields.get('methods','')+'\n'+fields.get('notes','')).splitlines():
  if line.strip() in NONOPERATING:continue
  if re.search(r'교외|답사|견학|대체.?출석|출석.?대체|체험.?학습|현장.?방문|(?i:field[ -]?(?:work|trip|visit)|excursion|off[ -]?campus|site[ -]?visit|museum[ -]?visit)',line):raise ValueError('Off-campus or substituted attendance requires actual location and operating review')
  if re.search(r'비대면|온라인|녹화|동영상|원격|[Oo]n[- ]?line|[Ww]ebex|[Zz]oom|협의',line):raise ValueError('Delivery or negotiated operating paragraph needs semantic review')
  if re.search(r'\d{1,2}:\d{2}|\d{1,2}시',line):raise ValueError('Operating paragraph separately specifies a clock for review')
 weekly=fields['weekly'];printed=[];canceled=[]
 for week in range(1,15):
  key=next((k for k in weekly if re.fullmatch(str(week)+r'(?:st|nd|rd|th)',k)),None)
  if key is None:raise ValueError('Current plan has no complete normal weekly dated coverage')
  chunks=printed_chunks(weekly[key])
  if len(chunks)!=1:raise ValueError('Normal week does not have one unambiguous printed date')
  day,text=chunks[0]
  if any(re.search(r'교외|답사|견학|대체.?출석|출석.?대체|체험.?학습|현장.?방문|(?i:field[ -]?(?:work|trip|visit)|excursion|off[ -]?campus|site[ -]?visit|museum[ -]?visit)',line) and line.strip() not in NONOPERATING for line in text.splitlines()):raise ValueError('Printed dated off-campus or substituted attendance needs actual operating review')
  if day.isoweekday()!=weekday:raise ValueError('Printed date and current weekday disagree')
  first=date(2026,9,1)
  first+=timedelta(days=(weekday-first.isoweekday())%7)
  if day!=first+timedelta(weeks=week-1):raise ValueError('Printed date and source week disagree')
  if re.search(r'녹화|동영상|온라인|원격|비대면|[Rr]ecorded|[Aa]synchr|[Oo]n[- ]?line|[Ww]ebex|[Zz]oom',text):raise ValueError('Dated delivery requires separate semantic review')
  holiday_labels={date(2026,9,24):r'추석|[Cc]huseok|中秋',date(2026,9,25):r'추석|[Cc]huseok|中秋',date(2026,10,5):r'개천절|대체|[Ss]ubstitute|[Nn]ational [Ff]oundation',date(2026,10,9):r'한글날|[Hh]ang(?:eul|ul)'}
  explicit_cancellation=bool(re.search(r'휴강|휴업|휴교|수업은? ?없|no\s*class|休講',text,re.I))
  named_published_holiday=day in holiday_labels and bool(re.search(holiday_labels[day],text))
  if explicit_cancellation or named_published_holiday:canceled.append(day.isoformat());continue
  if day in [date(2026,9,24),date(2026,9,25),date(2026,10,5),date(2026,10,9)]:raise ValueError('Holiday date printed as class without explicit operating proof')
  if re.search(r'[Mm]id.?term|중간.*(?:고사|시험)',text) and not date(2026,10,20)<=day<=date(2026,10,26):raise ValueError('Printed midterm date conflicts with official exam period')
  printed.append(day)
 for key in ['15th','16th']:
  text=weekly.get(key,'')
  if not text:continue
  chunks=printed_chunks(text)
  if not chunks:raise ValueError('Makeup/final week lacks an explicit date')
  for day,chunk in chunks:
   if any(re.search(r'교외|답사|견학|대체.?출석|출석.?대체|체험.?학습|현장.?방문|(?i:field[ -]?(?:work|trip|visit)|excursion|off[ -]?campus|site[ -]?visit|museum[ -]?visit)',line) and line.strip() not in NONOPERATING for line in chunk.splitlines()):raise ValueError('Additional off-campus operating location requires independent review')
   if day.isoweekday()!=weekday or not date(2026,12,8)<=day<=date(2026,12,21):raise ValueError('Additional date has no consistent published weekday/semester')
   if re.search(r'온라인|녹화|동영상|비대면|원격|[Oo]nline|[Ww]ebex|[Zz]oom|추후|협의|예정',chunk):raise ValueError('Additional meeting operation is unresolved')
   if re.search(r'\d{1,2}:\d{2}|\d{1,2}시',chunk):raise ValueError('Separately printed clock requires independent review')
   if re.search(r'휴강|휴업|[Nn]o [Cc]lass',chunk):canceled.append(day.isoformat());continue
   if re.search(r'[Ff]inal|기말.*(?:시험|고사)',chunk):
    if not date(2026,12,15)<=day<=date(2026,12,21):raise ValueError('Final exam date conflicts with official exam period')
   elif not date(2026,12,8)<=day<=date(2026,12,14):raise ValueError('Makeup date conflicts with official makeup period')
   printed.append(day)
 if len(printed)!=len(set(printed)):raise ValueError('Duplicate actual teaching date')
 result=copy.deepcopy(course)
 result['schedules']=[{**fixed,'date':day.isoformat()} for day in sorted(printed)]
 result['scheduleStatus']='scheduled'
 result['period']={'startDate':'2026-09-01','endDate':'2026-12-21'}
 return result,{'sourceUrl':document['sourceUrl'],'printedDates':[d.isoformat() for d in sorted(printed)],'printedCanceledDates':canceled,'clockProof':'derivedFromSameCurrentPlanFixedPeriodHeaderAndCurrentOfficialCampusClock','roomProof':'sameCurrentPlanFixedClassroomHeader','sourceRepeatedRule':{'weekday':weekday,'startMinute':fixed['startMinute'],'endMinute':fixed['endMinute'],'classroom':fixed['classroom']},'derivedDates':False,'derivedClock':True}

if __name__=='__main__':
 reviewed=[];blocked=[]
 for campus,source in [('seoul','H1'),('global','H2')]:
  ordinary=load(ROOT/f'hufs-{campus}-2026-2.whole-candidate.json')
  gated=load(ROOT/f'hufs-{campus}-2026-2.operating-review-candidate.json')
  byid={c['sourceId']:c for c in gated['courses']}
  for course in ordinary['courses']:
   if not course['schedules']:continue
   document=load(ROOT/'hufs-public-operating-plans'/f"{source}-{course['courseCode']}{course['section']}.json")
   # Only fully slash-dated plans are attempted in this narrow first pass.
   try:
    document=normalize_year_first_or_last_dates(document)
    if not all(printed_chunks(v) for k,v in document['fields']['weekly'].items() if re.fullmatch(r'(?:[1-9]|1[0-4])(?:st|nd|rd|th)',k)) or len(document['fields']['weekly'])<14:continue
    updated,proof=normalize(course,document)
   except ValueError as error:blocked.append({'sourceId':course['sourceId'],'reason':str(error)});continue
   byid[course['sourceId']]=updated;reviewed.append({'sourceId':course['sourceId'],**proof})
  gated['courses']=[byid[c['sourceId']] for c in gated['courses']]
  gated['schemaVersion']=2
  (ROOT/f'hufs-{campus}-2026-2.dated-reviewed-candidate.json').write_text(json.dumps(gated,ensure_ascii=False,indent=2))
 audit={'researchOnly':True,'completionClaim':False,'wholeSemanticReviewComplete':False,'reviewedCount':len(reviewed),'reviewed':reviewed,'attemptedUnresolved':blocked}
 (ROOT/'hufs-explicit-dated-reviewed-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
 print('Printed complete dated plans reviewed:',len(reviewed),'unresolved attempted:',len(blocked))
