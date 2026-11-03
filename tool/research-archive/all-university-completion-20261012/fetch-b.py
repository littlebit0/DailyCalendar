import urllib.request,concurrent.futures,json
from pathlib import Path
p=Path('work/all-university-completion-20261012/b-sources')
urls={'jeju-multi':'https://www.jejunu.ac.kr/admission/eduguide/edu/graduate/subject.htm','khu-system':'https://haksa.khu.ac.kr/nhaksa/user/contents/view.do?menuNo=21200061','jnu-greenbio':'https://greenbio.jnu.ac.kr/greenbio/21275/subview.do','kookmin-hat':'https://hat.kookmin.ac.kr/','knu-system':'https://www.knu.ac.kr/wbbs/wbbs/contents/index.action?menu_idx=&menu_url=edu%2Facademic03_01_12','knu-2026':'https://www.knu.ac.kr/wbbs/wbbs/bbs/btin/stdViewBtin.action?btin.bltn_no=11778827581039&menu_idx=42','knu-2023':'https://www.knu.ac.kr/wbbs/wbbs/bbs/btin/stdViewBtin.action?btin.bltn_no=11699424878979&btin.inpt_nbr=2020597&menu_idx=42','kmu-kcloud':'https://kmu.ac.kr/uni/main/page.jsp?mnu_uid=3974','kmu-book':'https://dept.kmu.ac.kr/pdfView/webtoon/43/72/fileDownload.do','korea-system':'https://registrar.korea.ac.kr/eduinfo/info/major_convergence.do','cnu-linked':'https://plus.cnu.ac.kr/html/hub/academic/academic_01021104.html','kyonggi-colleges':'https://www.kyonggi.ac.kr/www/contents.do?key=5157'}
def get(z):
 n,u=z
 try:
  b=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read();f=p/(n+('.pdf'if b.startswith(b'%PDF')else'.html'));f.write_bytes(b);return dict(key=n,url=u,sourceFile=str(f),bytes=len(b))
 except Exception as e:return dict(key=n,url=u,error=str(e))
r=list(concurrent.futures.ThreadPoolExecutor(8).map(get,urls.items()));(p/'receipts.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print(r)
