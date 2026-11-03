import urllib.request,concurrent.futures,pathlib,json
P=pathlib.Path('work/course-owner-filter-20261012/c-sources');urls={'pnu':'https://www.pusan.ac.kr/kor/Main.do','postech':'https://www.postech.ac.kr/','sangji':'https://www.sangji.ac.kr/kor/','sch':'https://homepage.sch.ac.kr/','scnu':'https://www.scnu.ac.kr/SCNU/main.do','sejong':'https://www.sejong.ac.kr/','seoultech':'https://www.seoultech.ac.kr/','sku':'https://www.skuniv.ac.kr/','smu-cheonan':'https://www.smu.ac.kr/ko/edu/cheonan001.do','sogang':'https://www.sogang.ac.kr/','sookmyung':'https://www.sookmyung.ac.kr/kr/index.do','sungkyul':'https://www.sungkyul.ac.kr/','sunmoon':'https://lily.sunmoon.ac.kr/','swu':'https://www.swu.ac.kr/','syu':'https://www.syu.ac.kr/','tuk':'https://www.tukorea.ac.kr/tukorea/index.do','ulsan':'https://www.ulsan.ac.kr/kor/Main.do','unist':'https://www.unist.ac.kr/','uos':'https://www.uos.ac.kr/kor/main.do','ut':'https://www.ut.ac.kr/kor.do','wsu':'https://www.wsu.ac.kr/','yongin':'https://www.yongin.ac.kr/','yu':'https://www.yu.ac.kr/main/index.do'}
def get(a):
 k,u=a
 try:
  with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25)as r:b=r.read();enc=r.headers.get_content_charset() or 'utf-8';url=r.url
  s=b.decode(enc,errors='replace');P.joinpath(k+'-home.html').write_text(s);return dict(university=k,sourceUrl=url,file=str(P/(k+'-home.html')),bytes=len(b))
 except Exception as e:return dict(university=k,sourceUrl=u,error=str(e))
rs=list(concurrent.futures.ThreadPoolExecutor(max_workers=8).map(get,urls.items()));P.joinpath('home-receipts.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2));print(rs)
