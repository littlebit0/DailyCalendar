import json,re,sys
from pathlib import Path
sys.path.insert(0,'/private/tmp/daily-college-source-parser')
from bs4 import BeautifulSoup
O=Path('work/all-university-completion-20261012');a=json.load(open('assets/timetable/organizations/kangwon.json'))
cm={'춘천캠퍼스':'chuncheon','강릉캠퍼스':'gangneung','삼척캠퍼스':'samcheok','원주캠퍼스':'wonju'}
norm=lambda t:re.sub(r'\s+','',t)
entries={}
for r in json.load(open('work/college-major-filters-20261012/b-sources/kangwon-receipts.json')):
 if 'sourceFile'not in r:continue
 p=Path(r['sourceFile']);s=BeautifulSoup(p.read_text(),'html.parser');main=s.select_one('main#content')
 if not main:continue
 tab=main.select_one('.major-tab-container')
 if not tab:continue
 members=[e.get_text(' ',strip=True)for e in tab.find_all('a')if'소개'not in e.get_text()]
 for m in a['mappings']:
  if m['college']is not None or m['campus']!=cm[r['campus']]:continue
  d=m.get('department')or''
  matched=[u for u in members if norm(d)==norm(u)or d.startswith(u+' ')]
  if not matched:continue
  entries[(m['campus'],m['sourceLabel'])]={'university':'kangwon','campus':m['campus'],'sourceLabel':m['sourceLabel'],'department':d,'college':r['college'],'group':None,'officialGroups':[],'kind':'ordinaryCollege','sourceUrl':r['url'],'sourceFile':str(p),'evidence':'공식 캠퍼스 '+r['campus']+' '+r['college']+' 본문 major-tab-container 학사 소속목록 정확 '+matched[0]+'; native학부 및 하위전공 원문소속을 같은 일반대학으로 적용, 사이트 전역메뉴/다른캠퍼스 소속 미사용'}
(O/'kangwon-exact-b.json').write_text(json.dumps({'entries':list(entries.values())},ensure_ascii=False,indent=2));print(len(entries));print([(e['campus'],e['department'],e['college'])for e in entries.values()])
