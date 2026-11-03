exec(open('work/all-university-completion-20261012/fetch-b.py').read().split('r=list(')[0])
urls={'korea-regulation': 'https://registrar.korea.ac.kr/_res/eduinfo/etc/affairs_academicRegu01.pdf', 'korea-human-digital': 'https://libart.korea.ac.kr/libart/major/units/sts.do', 'korea-ai': 'https://cs.korea.ac.kr/cs/under/ai_intro.do', 'korea-2026-alt': 'https://gchina.korea.ac.kr/bbs/gchina/447/178375/download.do', 'hongik-program': 'https://ee.hongik.ac.kr/ee/0501.do?articleNo=153636&mode=view', 'iccu-program': 'https://eduinno.iccu.ac.kr/education/roadmap.php', 'mju-program': 'https://mjhistory.mju.ac.kr/mjukr/9664/subview.do', 'kumoh-program': 'https://ce.kumoh.ac.kr/mse/sub0203.do?articleNo=575254&mode=view'}
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
