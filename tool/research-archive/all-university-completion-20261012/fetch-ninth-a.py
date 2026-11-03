exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'hansei-2026-curriculum-record':'https://www.hansei.ac.kr/view.do?no=10226&pgMode=show&pstSn=30623'}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-ninth.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
