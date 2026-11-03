"""Fetch documented anonymous educational plans, never user accounts.

All public template contact/office rows are excluded. No raw pages/session values
are persisted. Unpublished/error plans are recorded without authentication retry.
"""
import argparse,hashlib,json,re,time,urllib.parse,urllib.request
from pathlib import Path
from html import escape
from lxml import html
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--limit',type=int,default=30);args=parser.parse_args()
old=json.loads((ROOT.parent/'catalogs/khu-public-all-query-rows.json').read_text())
unique={}
for r in old:
 if r['haksu_code'] or r['teach_cd']=='NONE':continue
 unique.setdefault((r['campus_nm'],r['lecture_cd'],r['teach_cd']),r)
from khu_educational_plan import educational_page

directory=ROOT/'public-plans-v2';directory.mkdir(exist_ok=True);audit=[];fresh=0
for index,(key,r) in enumerate(unique.items(),1):
 ident=hashlib.sha256('|'.join(key).encode()).hexdigest()[:20];file=directory/f'{ident}.json'
 if file.exists():continue
 if fresh>=args.limit:break
 params=dict(attribute='lectPlan',p_year='2026',p_term='20',p_teach=key[2],p_code=r['lecture_cd'],p_subjt=r['subjt_cd'],lang='ko',loginYn='N',schedule_cd='hakbu')
 url='https://sugang.khu.ac.kr/core?'+urllib.parse.urlencode(params)
 req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','Referer':'https://sugang.khu.ac.kr/login?attribute=loginMain&lang=ko&loginYn=N&schedule_cd=hakbu'})
 try:
  with urllib.request.urlopen(req,timeout=35) as response:body=response.read().decode('utf-8')
  header,sections=educational_page(body)
  if not any('2026학년도 2학기' in h for h in header):raise ValueError('Current public semester header missing')
  codes=[row[i+1] for s in sections if s['section']=='기본정보' for row in s['rows'] for i in range(0,len(row)-1,2) if row[i]=='학수번호']
  if r['lecture_cd'] not in codes:raise ValueError('Public native code/header mismatch')
  names=[row[i+1] for section in sections if section['section']=='기본정보' for row in section['rows'] for i in range(0,len(row)-1,2) if row[i]=='교강사명']
  expected=re.sub(r'\s+','',r['teach_na'])
  normalized=[re.sub(r'\s+','',name) for name in names]
  if not any(name==expected or (name.startswith(expected+'(') and name.endswith(')')) for name in normalized):raise ValueError('Published teacher-name mismatch')
  result={'campus':r['campus_nm'],'lectureCode':r['lecture_cd'],'displayCode':r['lecture_cd_disp'],'queriedProfessorName':r['teach_na'],'checkedAt':'2026-10-08','header':header,'educationalSections':sections,'publicSourceBodySHA256':hashlib.sha256(body.encode()).hexdigest(),'source':'https://sugang.khu.ac.kr/core?attribute=lectPlan','authenticationUsed':False}
  file.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');audit.append({'file':file.name,'displayCode':r['lecture_cd_disp'],'status':'publicCurrentHeaderVerified'})
 except Exception as error:
  audit.append({'displayCode':r['lecture_cd_disp'],'status':'held','errorType':type(error).__name__})
 fresh+=1;time.sleep(.35)
 if fresh%10==0:print(f'Queried {fresh} public plans this pass; current education retained {sum(x["status"]=="publicCurrentHeaderVerified" for x in audit)}',flush=True)
(ROOT/f'khu-plan-v2-query-audit-{len(list(directory.glob("*.json")))}-20261008.json').write_text(json.dumps({'queriedThisPass':fresh,'currentPlanFiles':len(list(directory.glob('*.json'))),'wholeDistinctPublicTeacherPlans':len(unique),'records':audit,'completionClaim':False,'wholeOperatingReviewComplete':False,'contactOfficeAndStaffIdentifiersNotSaved':True},ensure_ascii=False,indent=2)+'\n');print('Pass completed; whole operation remains unapproved.',flush=True)
