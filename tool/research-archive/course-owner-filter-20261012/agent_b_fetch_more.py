exec(open('work/course-owner-filter-20261012/agent_b_fetch.py').read().split('urls=')[0])
root=Path('work/course-owner-filter-20261012')
urls={'korea':'https://www.korea.ac.kr/ko/418/subview.do','kunsan':'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000101012000000&sso=ok','koreatech':'https://www.koreatech.ac.kr/kor/index.jsp','iccu':'https://nursing.iccu.ac.kr/intro/introduce.php','mmu':'https://mobility.mmu.ac.kr/admission/contents/naval','nsu':'https://www.nsu.ac.kr/?m1=page%25&menu_id=33','korea-sejong':'https://sejong.korea.ac.kr/mbshome/mbs/kr/subview.do?id=kr_020100000000'}
def fetch(pair):
 u,url=pair
 try:
  r=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30);raw=r.read();s=raw.decode('utf-8',errors='replace');f=root/(u+'-official-overview.html');f.write_text(s);return dict(university=u,url=url,sourceFile=str(f),length=len(s))
 except Exception as e:return dict(university=u,url=url,error=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 results=[]
 for r in pool.map(fetch,urls.items()):results.append(r);print(r['university'],r.get('length',r.get('error')),flush=True)
(root/'agent-b-overview-receipts.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
