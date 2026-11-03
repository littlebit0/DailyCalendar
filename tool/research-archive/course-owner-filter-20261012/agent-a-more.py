import pathlib,urllib.request,concurrent.futures,json
from lxml import html
S=pathlib.Path('work/course-owner-filter-20261012/agent-a-sources')
u={'ajou-colleges':'https://www.ajou.ac.kr/kr/admission/list01.do','ewha-colleges':'https://www.ewha.ac.kr/ewha/academics/college.do','hanyang-seoul':'https://www.hanyang.ac.kr/s_college_department-info','hanyang-erica':'https://www.hanyang.ac.kr/e_college_department-info','hansung-colleges':'https://www.hansung.ac.kr/hansung/6208/subview.do','gknu-current':'https://www.gknu.ac.kr/main/html.do?menu_idx=680'}
def fetch(t):
 k,url=t
 try:
  x=urllib.request.urlopen(url,timeout=25);s=x.read().decode(x.headers.get_content_charset() or 'utf-8',errors='replace');(S/(k+'.html')).write_text(s);return k,url,None
 except Exception as e:return k,url,str(e)
r=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(fetch,u.items()));json.dump(r,open(S/'more-index.json','w'),ensure_ascii=False,indent=2)
for k,url,e in r:
 if e:print(k,e);continue
 root=html.fromstring((S/(k+'.html')).read_text());print(k)
 word={'ajou-colleges':'심리학과','ewha-colleges':'경제학과','hanyang-seoul':'건설환경공학과','hanyang-erica':'기계공학과','hansung-colleges':'크리에이티브','gknu-current':'뷰티학전공'}[k]
 aa=root.xpath(f'//*[contains(text(),"{word}")]')
 if aa:print(html.tostring(aa[-1].getparent().getparent(),encoding='unicode')[:3500])
