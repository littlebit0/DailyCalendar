exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'dgist-2026-curriculum.pdf':'https://www.dgist.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000167385Jr7&fileSn=0','dgist-2026-curriculum.xlsx':'https://www.dgist.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000167385Jr7&fileSn=1'}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-dgist-2026.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
