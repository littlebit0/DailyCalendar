"""Prepare current public offerings, preserving incomplete scheduling explicitly.

No production registration. Keyword matches are reviewed independently; uncertain
mixed/VOD/makeup/exam clocks never become a made-up weekly meeting.
"""
import datetime as dt
import importlib.util
import json
from pathlib import Path
import re
import sys
from collections import Counter
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from generate_seoultech_dated_fixture import course as dated_course
spec=importlib.util.spec_from_file_location('seoultech_clock',ROOT.parents[2]/'tool/timetable/import_seoultech.py')
clock=importlib.util.module_from_spec(spec);spec.loader.exec_module(clock)
START=dt.date(2026,9,1);END=dt.date(2026,12,14)
# These exact rows were read: matches concern lesson content, assignment delivery,
# supplemental materials, or a conditional fallback, not a changed teaching clock.
SAFE_CONTENT=set('''100841-11009 100841-11004 100842-11007 100379-31001
143430-41001 104700-21003 100682-31001 100841-11003 100842-11001
116589-21002 123837-21001 109114-41003 109114-41009 109004-11003
109038-31001 109038-31002 104726-31001 109130-31001 100842-11003
116589-21001 839997-11001 116595-31001 147152-31001 100425-31005
100425-31006 137026-31001 100682-31002 126350-21001
100166-11001 100211-31001 100211-31002 100211-31003 100211-31004
100211-31005 100211-31006 100211-31007 100356-31001 100473-31002
100490-11001 100490-11002 104025-21001 104025-21002 126248-21001
146040-21001 191013-21004 193011-21002 193011-21003 193035-31001
500602-31001 100342-31001 100693-31001 100693-31002 100785-31001
109481-31001 115564-31001 120113-41002 137068-31001 186010-21002
186010-21003 187010-21001 187010-21002 800030-21001'''.split())
# Current published weekly rows explicitly provide all 15 actual lesson dates.
FULL_DATED={'100057-31002','100057-31003','901035-21001','901036-21001','130141-41001'}
# Explicit current VOD substitution dates; other printed weekly clocks survive.
VOD_DATES={k:{dt.date(2026,9,25),dt.date(2026,10,9)} for k in ['101068-11017','100766-31009','100766-31010','100046-31001','100829-31011']}
VOD_DATES['100473-31004']={dt.date(2026,9,25)}
VOD_DATES['193007-21002']={dt.date(2026,9,24),dt.date(2026,10,22),dt.date(2026,12,10)}

def load(name):return json.loads((ROOT/name).read_text())
def plan(key):return load('seoultech-public-plans/'+key+'.json')
def dates_from_text(text):
 return {dt.date(2026,int(m),int(d)) for m,d in re.findall(r'(?<![\d.])(\d{1,2})\s*(?:/|월)\s*(\d{1,2})(?:\s*일)?',text)}
def specific_weeks(key,meetings):
 document=plan(key);out=[];all_dates=[]
 if len(meetings)!=1:raise ValueError('Exact dated plan has ambiguous weekday blocks')
 for week in range(1,16):
  candidates=[]
  for prefix in ['TASK_NOTT_','COUS_CONT_']:
   text=document.get(prefix+str(week)) or ''
   dates=dates_from_text(text)
   if dates:
    if len(dates)!=1:raise ValueError('Multiple current week dates')
    candidates.append((next(iter(dates)),text))
  if not candidates or len({x[0] for x in candidates})!=1:raise ValueError('Missing or conflicting printed week date')
  date=candidates[0][0];all_dates.append(date);text=' '.join(t for _,t in candidates)
  if date.isoweekday()!=meetings[0]['weekday'] or not START<=date<=END:raise ValueError('Date outside current semester/weekday')
  if re.search(r'VOD|동영상|수업\s*없|No class',text,re.I):continue
  m={**meetings[0],'date':date.isoformat()}
  if re.search(r'대면|오프라인|Face-to-face',text,re.I):m['deliveryMode']='inPerson'
  out.append(m)
 if len(set(all_dates))!=15 or any(b-a!=dt.timedelta(days=7) for a,b in zip(all_dates,all_dates[1:])):raise ValueError('Printed teaching dates not complete sequential 15 weeks')
 return out

def dated_without_vod(key,meetings):
 # These exact source statements were independently read, not regex guesses.
 document=plan(key);texts='\n'.join(str(v) for k,v in document.items() if k.startswith(('TASK_','COUS_')))
 if key!='193007-21002' and not re.search(r'동\s*영상',texts):raise ValueError('VOD evidence missing')
 if key=='193007-21002' and not all(s in texts for s in ['10/22 No class','12/10 No class','Watching the videos']):raise ValueError('Explicit canceled dates missing')
 out=[];date=START
 while date<=END:
  if date not in VOD_DATES[key]:
   out.extend({**m,'date':date.isoformat()} for m in meetings if date.isoweekday()==m['weekday'])
  date+=dt.timedelta(days=1)
 return out

def unambiguous_room(text):
 """Use a unique published room only; no positional group-to-room pairing."""
 if not text:
  return ''
 groups=list(re.finditer(r'(.+?-[A-Za-z0-9]+)(?:\s+|$)',text.strip()))
 if not groups or ''.join(m[0] for m in groups).strip()!=text.strip():
  return ''
 rooms={m[1].strip() for m in groups}
 return next(iter(rooms)) if len(rooms)==1 else ''

def base(row):
 key=row['SUBJ_CD']+'-'+row['LECT_NUMB'];department=row['SP_LESS_CD_NM'];credits=float(row['UNIT'])
 if not re.fullmatch(r'\d{6}-\d{5}',key) or not 0<=credits<=30:raise ValueError('Invalid offering identity or credits')
 remarks=[str(row[k]).strip() for k in ['NOTE','ETC'] if row.get(k)]
 for field,label in [('OTSH_LIMT_YN','타교생 제한'),('DLES_COUR_PBT_YN','타과 제한')]:
  if row.get(field) not in ['Y','N',None]:raise ValueError('Unknown restriction')
  if row.get(field)=='Y':remarks.append(label)
 if row.get('COUR_LANG'):remarks.append('수업 언어: '+row['COUR_LANG'])
 return {'sourceId':f"seoultech/main/2026/2/{row['SUBJ_CD']}/{row['LECT_NUMB']}",'campus':'main','academicYear':2026,'semester':'2','courseCode':row['SUBJ_CD'],'section':row['LECT_NUMB'],'courseName':row['SUBJ_KNM'],'professor':row.get('PROF_NM') or '', 'credits':credits,'schedules':[],'scheduleStatus':'unscheduled','sourceSchedule':row.get('LSTM_LIST') or '', 'sourceClassroom':row.get('BLDG_COUM') or '', 'departments':[department],'departmentCredits':{department:credits},'departmentClassifications':{department:row['CMPT_DIV_NM']},'departmentRemarks':{department:'\n'.join(remarks)}}

def generate():
 rows=load('seoultech-current-educational-20261008.json');dated={p.stem:json.loads(p.read_text()) for p in (ROOT/'seoultech-future-public-schedules').glob('*.json')}
 contexts={}
 for filename in ['seoultech-current-plan-exception-contexts.json','seoultech-current-additional-operating-contexts.json','seoultech-current-extra-mode-contexts.json']:
  for c in load(filename)['courses']:contexts.setdefault(c['key'],[]).extend(c['fields'])
 merges={r['code']+'-'+r['section']:r['remark'] for r in load('seoultech-current-closures-audit.json')['mergedStatus']}
 courses=[];decisions=[]
 for row in rows:
  key=row['SUBJ_CD']+'-'+row['LECT_NUMB'];c=base(row);kind='sourceUntimed';reason=''
  if key in dated:
   c=dated_course(row,dated[key]);kind='publishedDated'
  else:
   try:
    meetings=clock.regular_meetings(c['sourceSchedule'])
    room=unambiguous_room(c['sourceClassroom'])
    if room:
     for meeting in meetings:meeting['classroom']=room
   except ValueError:meetings=[];kind='unrecognized';reason='현재 공식 자료에서 A/B 교시의 시각을 확인할 수 없습니다.'
   if meetings:
    if key in FULL_DATED:c['schedules']=specific_weeks(key,meetings);kind='verifiedPlanDated'
    elif key in VOD_DATES:c['schedules']=dated_without_vod(key,meetings);kind='verifiedNoClassDated'
    elif key in contexts and key not in SAFE_CONTENT:
     kind='unrecognized';reason='공개 수업계획에 별도 시험·보강·녹화·혼합 수업 등 운영 예외가 있어 전체 날짜와 시각을 확정할 수 없습니다.'
    else:c['schedules']=meetings;kind='regular'
   if reason:c['scheduleStatus']='unrecognized'
   elif c['schedules']:c['scheduleStatus']='scheduled'
  if reason:
   for dept in c['departments']:c['departmentRemarks'][dept]+='\n'+reason
  if key in merges:
   for dept in c['departments']:c['departmentRemarks'][dept]+='\n합강 안내: '+merges[key]
  # Retain selected literal operating notes in research audit, not entire syllabus.
  decisions.append({'key':key,'decision':kind,'reason':reason,'reviewedFields':sorted({x['field'] for x in contexts.get(key,[])})})
  courses.append(c)
 result={'schemaVersion':2,'universityId':'seoultech','campus':'main','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://for-s.seoultech.ac.kr/html/pub/schedule.jsp','researchOnly':True,'completionClaim':False,'wholeUniversity':True,'courses':courses}
 (ROOT/'seoultech-main-2026-2.whole-candidate.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
 audit={'researchOnly':True,'completionClaim':False,'productionActivationComplete':False,'courseCount':len(courses),'decisions':decisions,'counts':dict(Counter(x['decision'] for x in decisions)),'publicPlanCount':1968,'unpublishedPlans':load('seoultech-current-plan-audit.json')['unpublished'],'calendar':{'sourceUrl':'https://aai.seoultech.ac.kr/bachelor/bachelor?year=2026&typ=3','startDate':'2026-09-01','regularEndDate':'2026-12-14','conditionalMakeupStart':'2026-12-15','conditionalMakeupEnd':'2026-12-21','publishedEndDate':'2026-12-21'}}
 (ROOT/'seoultech-whole-prepared-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print(audit['counts'])
if __name__=='__main__':generate()
