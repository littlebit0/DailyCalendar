from pathlib import Path
import urllib.request,json
p=Path(__file__).parent
urls={
'skku-2026-calendar.html':'https://www.skku.edu/skku/edu/bachelor/ca_de_schedule.do?mode=view&srBachelorYear=2026',
'hanyang-erica-2026-2-period.html':'https://site.hanyang.ac.kr/ko/web/ehaksa/-120',
'hanyang-seoul-2026-2-period.html':'https://site.hanyang.ac.kr/web/academic/-16in',
'yonsei-sinchon-2026-2-notice.html':'https://www.yonsei.ac.kr/bbs/sc/58/943624/artclView.do',
'yonsei-mirae-2026-2-notice.html':'https://www.yonsei.ac.kr/bbs/wj/104/943625/artclView.do',
'skku-2026-freshmen-login-guide.html':'https://skb.skku.edu/aicon/notice.do?article.offset=0&articleLimit=10&articleNo=212456&mode=view',
}
for n,u in urls.items():
 try:
  r=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30);b=r.read();(p/n).write_bytes(b);print(n,r.status,len(b))
 except Exception as e:print(n,type(e).__name__,str(e))
(p/'public-evidence-urls.json').write_text(json.dumps(urls,ensure_ascii=False,indent=2))
