from pathlib import Path
import json,re,unicodedata,openpyxl
p=Path(__file__).parent;old=json.loads(Path('assets/timetable/inje-gimhae-2026-2.json').read_text())['courses'];native=json.loads((p/'inje-native-all-public-rows.json').read_text());by={(r['교과목'],r['분반']):r for r in native};reports=[json.loads(f.read_text())for f in(p/'report-fields').glob('*.json')]
s=openpyxl.load_workbook('work/university-research/expansion17-20261011/a/inje-globalbiz.xlsx',data_only=True)['2026-2학기 글로벌경영학과 시간표 (3안)']
clock={}
for row in range(6,17):
 text=s.cell(row,2).value;period=s.cell(row,1).value;times=re.findall('(\\d+):(\\d+)',text or'')
 if len(times)==2:clock[int(period)]=tuple(int(h)*60+int(m)for h,m in times)
weekday={'월':1,'화':2,'수':3,'목':4,'금':5,'토':6,'일':7}
def norm(t):return re.sub('\\s+','',unicodedata.normalize('NFKC',t or'')).casefold()
def room(t):
 m=re.fullmatch('([A-Z])(?:동)?(\\d+(?:-\\d+)?)',t or'');return m.groups()if m else None
out=[]
for o in old:
 evidence=[];held=[];headers=[]
 for cell in o.get('sourceCells',[]):headers.append(str(s.cell(5,s[cell].column).value))
 grades={h for h in headers if h.isdigit()};grade=next(iter(grades))if len(grades)==1 and len(grades)==len(set(headers))else None
 aliases=[]
 for r in reports:
  info=r.get('courseInformation',{});title=info.get('교과목명','');parts=[title.split('(')[0]]+re.findall(r'\(([^()]*)\)',title)
  if not any(norm(o['courseName'])==norm(x)for x in parts):continue
  reasons=[]
  if norm(o['professor'])!=norm(r.get('professorName')):reasons.append('professor not exact')
  target=info.get('수강대상')or by[(r['code'],r['section'])].get('개설학과','')
  if grade is None:reasons.append('original grade header ambiguous')
  elif f'글로벌경영학과({grade})'not in target:reasons.append('globalbusiness/grade target not exact')
  blocks=[]
  for m in re.finditer(r'(?<![가-힣])([월화수목금토일])([0-9]+(?:,[0-9]+)*)\s*([A-Z](?:동)?\d+(?:-\d+)?)',info.get('수업시간강의실','')):
   nums=[int(x)for x in m.group(2).split(',')];blocks.append({'weekday':weekday[m.group(1)],'periods':nums,'room':room(m.group(3))})
  if len(blocks)!=len(o['schedules']):reasons.append('weekly block count differs')
  else:
   for a,b in zip(sorted(blocks,key=lambda x:(x['weekday'],x['periods'])),sorted(o['schedules'],key=lambda x:(x['weekday'],x['startMinute']))):
    if a['weekday']!=b['weekday']or a['room']!=room(b['classroom']):reasons.append('weekday/room differs');continue
    if any(n not in clock for n in a['periods']):reasons.append('native period absent original literal clock');continue
    if clock[min(a['periods'])][0]!=b['startMinute']or clock[max(a['periods'])][1]!=b['endMinute']:reasons.append('actual original clock span differs')
    if a['periods']!=list(range(min(a['periods']),max(a['periods'])+1)):reasons.append('native noncontiguous periods')
  e={'nativeCode':r['code'],'nativeSection':r['section'],'nativeTitle':title,'nativeProfessor':r.get('professorName'),'nativeTarget':target,'nativeSchedule':info.get('수업시간강의실'),'nativeClassMethod':info.get('수업방식_전체'),'nativeSourceUrl':r['sourceUrl'],'originalGradeHeaders':headers,'sameYearSemester':r.get('title')=='2026학년도 2학기 수업계획서','reasons':reasons,'nativeBlocks':blocks}
  (held if reasons else evidence).append(e)
 out.append({'originalSourceId':o['sourceId'],'originalRawObject':o,'originalLiteralClock':clock,'uniqueAllFieldsCandidate':evidence if len(evidence)==1 else[],'rawPassingCandidates':evidence,'heldAliases':held,'noAliasYet':not evidence and not held,'collectionComplete':False})
(p/'global16-native-physical-join-candidates.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print('unique',sum(bool(r['uniqueAllFieldsCandidate'])for r in out),'aliasheld',sum(bool(r['heldAliases'])for r in out),'noaliasyet',sum(r['noAliasYet']for r in out));print([(r['originalRawObject']['courseName'],r['uniqueAllFieldsCandidate'][0]['nativeCode'])for r in out if r['uniqueAllFieldsCandidate']])
