"""Prepare the whole public current HUFS source without invented clocks/modes."""
import copy,importlib.util,json,re
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('hufs_import',ROOT.parents[2]/'tool/timetable/import_hufs.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
def load(path):return json.loads(path.read_text())
manifest,rows=module.load_complete(ROOT/'hufs-current-20261008')
old=load(ROOT/'hufs-prior-current/courses.json')
key=lambda r:(r['queryCampus'],r['queryCategory'],r['queryDepartment'],r['row']['lssnCd'])
a={key(r):r['row'] for r in old};b={key(r):r['row'] for r in rows}
fresh={'researchOnly':True,'completionClaim':False,'checkedDate':'2026-10-08','displayRows':len(rows),'uniqueCourses':len({(r['queryCampus'],r['row']['lssnCd']) for r in rows}),'added':sorted(b.keys()-a.keys()),'removed':sorted(a.keys()-b.keys()),'changed':sorted(k for k in b.keys()&a.keys() if b[k]!=a[k])}
(ROOT/'hufs-current-refresh-audit.json').write_text(json.dumps(fresh,ensure_ascii=False,indent=2))
# Exactly printed hourly 50-minute guide entries. Period 13 is not present.
seoul={str(i):[s,e] for i,(s,e) in enumerate([(480,530),(540,590),(600,650),(660,710),(720,770),(780,830),(840,890),(900,950),(960,1010),(1020,1070),(1080,1130),(1140,1190),(1200,1250)])};clocks={'H1':seoul,'H2':{k:v for k,v in seoul.items() if k!='0'}}
late={'D03330101','D01355401','P04205206'}
cleaned=copy.deepcopy(rows)
for record in cleaned:
 if record['queryCampus']=='H1' and record['row']['lssnCd'] in late:record['row']['dayTimeDisplay']=''
courses=module.parse_rows(cleaned,clocks)
raw={(r['queryCampus'],r['row']['lssnCd']):r['row'] for r in rows}
plans={c['key']:c for c in load(ROOT/'hufs-current-special-plans-educational.json')['courses']}
ASYNC={'Q05005101','Q05006101'}
cyber={r['row']['lssnCd'] for r in rows if r['row']['cyberFlag']=='Y'}
audit=[]
for c in courses:
 c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 campus='H1' if c['campus']=='seoul' else 'H2';identity=c['courseCode']+c['section'];r=raw[(campus,identity)];reason='';decision='regular'
 if identity=='V43407301':
  if r['dayTimeDisplay']!='화 9 10 (2201)' or '17:10 시작' not in r['etc']:
   raise ValueError('Current published start override changed')
  if len(c['schedules'])!=1 or c['schedules'][0]['startMinute']!=1020 or c['schedules'][0]['endMinute']!=1130:
   raise ValueError('Unexpected published source period range')
  c['schedules'][0]['startMinute']=1030
 if identity in late:
  c['sourceSchedule']=module.clean(r['dayTimeDisplay']);c['sourceClassroom']=' / '.join(dict.fromkeys(re.findall(r'\(([^()]*)\)',c['sourceSchedule'])));reason='공식 현재 편람과 강의계획에 13교시의 실제 시작·종료 시각이 없습니다.'
 elif identity in cyber:
  if identity in ASYNC:
   decision='explicitAsynchronous';note=plans[identity]['fields']['notes']
   if '100% 비동기' not in note or '오프라인 참여 요소가 없습니다' not in note:raise ValueError('Asynchronous proof missing')
  else:
   reason='사이버 강의의 시험·실시간 토론·발표 운영에 대한 실제 날짜와 종료 시각을 공개 자료만으로 확정할 수 없습니다.'
 elif identity in ['M01401101','O13314201','N07360401']:
  # Weekly live mode is verified for N07360401, but source-preserving model
  # currently accepts deliveryMode only with exact dates. Keep review explicit.
  reason={'M01401101':'비대면 지도교수 협의 방식으로 실제 정기 수업 날짜·시각을 확정할 수 없습니다.','O13314201':'전체 온라인 수업이나 실시간과 녹화 운영 구분을 공개 자료만으로 확정할 수 없습니다.','N07360401':'실시간 온라인 정기 운영은 확인되지만 계획의 중간시험 주차와 공식 학사력 시험 주간이 달라 실제 시험·수업 날짜를 확정할 수 없습니다.'}[identity]
 elif not c['schedules']:decision='sourceUntimed'
 if reason:
  c['schedules']=[];c['scheduleStatus']='unrecognized';decision='unrecognized'
  for department in c['departments']:c['departmentRemarks'][department]+=' · '+reason
 if identity in cyber and identity in plans:
  if identity=='H01201101':
   for dept in c['departments']:c['departmentRemarks'][dept]+=' · 외국인 전용 강의: 외국인 학생이 아니면 수강 제한'
 audit.append({'campus':c['campus'],'identity':identity,'decision':decision,'reason':reason,'sourceUrl':plans.get(identity,{}).get('sourceUrl')})
for source,campus in module.CAMPUS_IDS.items():
 document={'schemaVersion':1,'universityId':'hufs','campus':campus,'campusName':module.CAMPUS_NAMES[source],'academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':manifest['sourceUrl'],'researchOnly':True,'completionClaim':False,'courses':[c for c in courses if c['campus']==campus]}
 (ROOT/f'hufs-{campus}-2026-2.whole-candidate.json').write_text(json.dumps(document,ensure_ascii=False,indent=2))
result={'researchOnly':True,'completionClaim':False,'productionActivationComplete':False,'counts':dict(Counter(r['decision'] for r in audit)),'campuses':dict(Counter(c['campus'] for c in courses)),'decisions':audit,'normalPeriod':{'start':'2026-09-01','end':'2026-12-07','makeup':['2026-12-08','2026-12-14'],'finals':['2026-12-15','2026-12-21'],'publishedEnd':'2026-12-21','sourceUrl':'https://www.hufs.ac.kr/schdulmanage/hufs/40/yearSchdul.do'},'wholeCurrentSource':True,'allOperatingPlansVerified':False}
(ROOT/'hufs-whole-prepared-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(fresh['uniqueCourses'],fresh['added'],fresh['removed'],len(fresh['changed']),result['counts'],result['campuses'])
