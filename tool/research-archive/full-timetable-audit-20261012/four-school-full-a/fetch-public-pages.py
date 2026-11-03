import pathlib,ssl,urllib.request,json,concurrent.futures
from lxml import html
P=pathlib.Path(__file__).parent
urls={'cbnu-login-public':'https://eisa.cbnu.ac.kr/atlecLogin','cbnu-main':'https://www.cbnu.ac.kr/www/index.do','gknu-main':'https://www.gknu.ac.kr/main/index.do','chosun-guide':'https://visual.chosun.ac.kr/acguide/9252/subview.do','donga-faq':'https://cms.donga.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN265'}
def fetch(x):
 key,url=x
 try:
  b=urllib.request.urlopen(url,context=ssl._create_unverified_context(),timeout=30).read();(P/(key+'.html')).write_bytes(b);t=html.fromstring(b);links=[{'label':' '.join(a.text_content().split()),'href':a.get('href')} for a in t.xpath('//a[@href]') if any(k in (a.text_content()+' '+a.get('href')) for k in ['시간표','교과목','수강','download','Download','File','파일'])];(P/(key+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return key,links
 except Exception as e:return key,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
 for v in ex.map(fetch,urls.items()):print(json.dumps(v,ensure_ascii=False))
