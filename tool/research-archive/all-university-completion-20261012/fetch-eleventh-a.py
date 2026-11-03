exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'dgist-current-curriculum':'https://www.dgist.ac.kr/bbs/BBSMSTR_000000000463.do','dgist-current-information':'https://www.dgist.ac.kr/college/sub03_04_03.do'}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-eleventh.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
