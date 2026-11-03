import pathlib,ssl,urllib.request,json,concurrent.futures
from lxml import html
P=pathlib.Path(__file__).parent/'root-followup-a-sources'
def fetch(item):
 key,url=item
 try:
  b=urllib.request.urlopen(url,context=ssl._create_unverified_context(),timeout=30).read();(P/(key+'.html')).write_bytes(b);t=html.fromstring(b);links=[{'label':a.text_content().strip(),'href':a.get('href')} for a in t.xpath('//a[@href]') if any(x in (a.get('href')+' '+a.text_content()) for x in ['download','Download','File','xlsx','pdf'])];[x.drop_tree() for x in t.xpath('//script|//style')];(P/(key+'-visible.txt')).write_text('\n'.join(x.strip() for x in t.xpath('//text()') if x.strip()));(P/(key+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2));return key,links
 except Exception as e:return key,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
 for v in ex.map(fetch,[('gnu-2026-2-notice','https://www.gnu.ac.kr/sophia/na/ntt/selectNttInfo.do?mi=3257&nttSn=7840121'),('chosun-2026-2-guide-notice','https://www4.chosun.ac.kr/bbs/cob/448/233401/artclView.do'),('donga-major-micro-modules','https://decore.donga.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN115')]):print(json.dumps(v,ensure_ascii=False))
