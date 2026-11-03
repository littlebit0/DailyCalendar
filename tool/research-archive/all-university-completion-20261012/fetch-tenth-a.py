exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'hansei-2026-full.pdf':'https://www.hansei.ac.kr/wcon/bbs/downFile.do?siteId=SITE003&bbsId=BRD0057&pstSn=30623&fileSn=24171'}
out=[one(k,u) for k,u in sources.items()];(p/'receipts-tenth.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
