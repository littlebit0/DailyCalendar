# -*- coding: utf-8 -*-
"""Exact displayed clocks only; no ordinal clock or course-period inference."""
from pathlib import Path
import json,re,collections
R=Path(__file__).resolve().parent
CLOCK=re.compile(r'([월화수목금토일])\s*(\d{1,2}):(\d{2})\s*~\s*(\d{1,2}):(\d{2})')
rows=json.loads((R/'cnu-current-catalog-education.json').read_text());out=[];unknown=[];counts=collections.Counter()
for row in rows:
 text=row.get('TMTBL_INFO') or '';matches=list(CLOCK.finditer(text));meetings=[];remaining=text[:matches[0].start()] if matches else text
 for index,m in enumerate(matches):
  tail=text[m.end():matches[index+1].start() if index+1<len(matches) else len(text)].strip().rstrip(",;").strip()
  location=""
  if tail:
   depth=0;balanced=tail.startswith("(") and tail.endswith(")")
   for pos,char in enumerate(tail):
    if char=="(":depth+=1
    elif char==")":depth-=1
    if depth<0 or (depth==0 and pos<len(tail)-1):balanced=False
   if balanced and depth==0:location=tail[1:-1]
   else:remaining+=tail
  sh,sm,eh,em=map(int,m.group(2,3,4,5));start=sh*60+sm;end=eh*60+em
  if sh>23 or eh>24 or sm>59 or em>59 or (eh==24 and em) or start>=end:
   remaining+='[invalidClock]';continue
  meetings.append({'weekday':'월화수목금토일'.index(m[1])+1,'startMinute':start,'endMinute':end,'location':location,'rawDisplayedClock':m[0]+tail})
 remaining=re.sub(r'[,;\s]+','',remaining)
 rowStatus='closed' if str(row.get('CLOSE_YN'))=='1' else 'blankTime' if not text.strip() else 'parsedExactClock' if meetings and not remaining else 'unresolvedClockText'
 counts[rowStatus]+=1
 if rowStatus=='unresolvedClockText':unknown.append({'courseId':row['COURSE_NO'],'originalTimetable':text,'unparsedEducationText':remaining})
 out.append({'courseId':row['COURSE_NO'],'status':rowStatus,'actualClockMeetings':meetings,'scheduleAllowed':False,'scheduleGate':'individual current operation and course date-period review remains pending; clock parse alone is not approval'})
(R/'cnu-current-clock-projection.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
(R/'cnu-current-clock-audit.json').write_text(json.dumps({'counts':dict(counts),'unknown':unknown,'ordinalClocksInvented':False,'courseDatesInvented':False,'wholeSupportComplete':False},ensure_ascii=False,indent=2));print(dict(counts));print('unresolved',len(unknown))
