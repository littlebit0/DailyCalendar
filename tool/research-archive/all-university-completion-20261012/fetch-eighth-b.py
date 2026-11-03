exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'pnu-linked':'https://con.pusan.ac.kr/con/74181/subview.do',
 'pknu-systems':'https://www.pknu.ac.kr/main/234',
 'changwon-systems':'https://www.changwon.ac.kr/icce/cm/cntnts/cntntsView.do?cntntsId=5368&mi=14917',
 'mokpo-systems':'https://www.mnu.ac.kr/www/246/subview.do',
 'gnu-systems':'https://map.gnu.ac.kr/main/cm/cntnts/cntntsView.do?cntntsId=1126&mi=1229',
 'khu-2026-guide':'https://physics.khu.ac.kr/upload/contents/202603/202603300353404720.pdf',
 'ewha-sports':'https://myr.ewha.ac.kr/convergence/major/physical-science.do',
 'ewha-science-ed':'https://teachers.ewha.ac.kr/teachers/major/science-education.do',
 'ewha-pharm-system':'https://cmsfox.ewha.ac.kr/pharm21/notice-board/notice.do?articleNo=740106&mode=view'}
r=list(concurrent.futures.ThreadPoolExecutor(8).map(get,urls.items()))
old=json.load(open(p/'receipts.json'));old.extend(r);(p/'receipts.json').write_text(json.dumps(old,ensure_ascii=False,indent=2))
from bs4 import BeautifulSoup
import fitz
for x in r:
 if 'sourceFile'not in x:continue
 f=Path(x['sourceFile'])
 if f.suffix=='.pdf': t='\n'.join(z.get_text()for z in fitz.open(f))
 else:t=BeautifulSoup(f.read_text(errors='replace'),'html.parser').get_text(' ',strip=True)
 f.with_suffix('.txt').write_text(t)
print(r)
