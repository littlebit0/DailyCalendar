exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'hansei-convergence':'https://www.hansei.ac.kr/view.do?no=12607','hansei-faculty':'https://www.hansei.ac.kr/view.do?no=12606','hansei-multi':'https://www.hansei.ac.kr/view.do?no=12084','hansei-micro':'https://www.hansei.ac.kr/view.do?no=12443','hansei-blockchain':'https://hansei.ac.kr/view.do?no=10252&pgMode=show&pstSn=30686','dgist-track':'https://mech.dgist.ac.kr/sub2_1_c.php'}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-seventh.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
