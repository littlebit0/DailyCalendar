exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={
 'inu-linked':'https://www.inu.ac.kr/clis/12662/subview.do',
 'kyonggi-2026':'https://enter.kyonggi.ac.kr/ajaxfile/CMN_SVC/FileView.do?CONTENTS_NO=1&GBN=X12&MENU_NO=180&SITE_NO=2&TYPE_CODE=C0601',
 'jnu-systems':'https://cvg.jnu.ac.kr/cvg/3600/subview.do',
 'jnu-linked':'https://engc.jnu.ac.kr/engc/2183/subview.do',
 'jeju-2024':'https://www.jejunu.ac.kr/ara/noticesurvey/degree.htm?act=download&no=4&page=1&seq=213810',
 'khu-all':'https://www.khu.edu/kor/user/contents/view.do?menuNo=200105',
 'khu-4d':'https://sdl.khu.ac.kr/bbs/download_pdf.php?file=2026_Global_4D_Arts.pdf',
 'korea-2026':'https://caas.korea.ac.kr/bbs/koreaSejong/656/177769/download.do',
 'jbnu-systems':'https://www.jbnu.ac.kr/web/academic/curriculum/sub04.do'}
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
