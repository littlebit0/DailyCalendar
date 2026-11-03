"""Normalize actual public undergraduate rows/details; no invented dates or slots."""
import json,re,pathlib,urllib.parse
ROOT=pathlib.Path(__file__).resolve().parent
DAYS='월화수목금토일'
def meetings(schedule,classrooms):
 if not schedule.strip():return [],'unscheduled'
 lines=[line.strip() for line in schedule.splitlines() if line.strip()]
 rooms=[line.strip() for line in classrooms.splitlines() if line.strip()]
 if len(lines)>1 and len(rooms)==1:
  return [],'unrecognized'
 if len(rooms) not in (0,1,len(lines)):raise ValueError('Room/time line count ambiguous')
 result=[]
 for i,line in enumerate(lines):
  match=re.fullmatch(r'([월화수목금토일](?:\s*,\s*[월화수목금토일])*)\s*/\s*(\d{2}):(\d{2})\s*~\s*(\d{2}):(\d{2})\s*/?',line)
  if not match:raise ValueError('Unrecognized actual published time')
  if int(match[3])>59 or int(match[5])>59:raise ValueError('Invalid minute')
  start=int(match[2])*60+int(match[3]);end=int(match[4])*60+int(match[5]);assert 0<=start<end<=1440
  room=rooms[i] if len(rooms)==len(lines) else rooms[0] if rooms else ''
  for day in re.findall('[월화수목금토일]',match[1]):
   row={'weekday':DAYS.index(day)+1,'startMinute':start,'endMinute':end,'classroom':room}
   if row not in result:result.append(row)
 return result,'scheduled'
def normalize(rows):
 result=[]
 for row in rows:
  id=urllib.parse.parse_qs(urllib.parse.urlparse(row['detailUrl']).query)['id'][0]
  detail=json.loads((ROOT/'postech-public-details'/f'{id}.json').read_text())
  if (detail['학수번호'],detail['분반'],detail['이수구분'],detail['이론-실습-학점'])!=(row['code'],row['section'],row['classification'],row['theoryPracticeCredits']):raise ValueError('List/detail mismatch')
  department=detail['학과'];credits=float(detail['학점']);assert department and credits>=0
  parsed,status=meetings(row['schedule'],row['classroom'])
  result.append({'sourceId':f'postech/main/2026/2/{id}','universityId':'postech','campus':'main','academicYear':2026,'semester':'2','courseCode':row['code'],'section':row['section'],'courseName':row['title'],'professor':row['professor'],'credits':credits,'departments':[department],'departmentCredits':{department:credits},'departmentClassifications':{department:row['classification']},'departmentRemarks':{department:'\n'.join(filter(None,[detail.get('강의유형코드'),detail.get('대상'),detail.get('성적부여방법'),detail.get('언어')]))},'sourceSchedule':row['schedule'],'sourceClassroom':row['classroom'],'scheduleStatus':status,'schedules':parsed})
 assert len({x['sourceId'] for x in result})==len(result)
 return result
if __name__=='__main__':
 rows=normalize(json.loads((ROOT/'postech-2026-2-undergraduate.json').read_text()))
 out={'researchOnly':True,'productionActivationComplete':False,'publishedDateMeaning':'Research capture date; administrative update timestamp not asserted','schemaVersion':1,'universityId':'postech','campus':'main','academicYear':2026,'semester':'2','publishedDate':'2026-10-07','sourceUrl':'https://plms.postech.ac.kr/local/ubion/course/lists.php?year=2026&semester=20&groupcode=U','courses':rows}
 (ROOT/'postech-2026-2-normalized-research.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
 print('normalized',len(rows),'timed',sum(x['scheduleStatus']=='scheduled' for x in rows),'untimed',sum(x['scheduleStatus']=='unscheduled' for x in rows))
