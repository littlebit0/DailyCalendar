exec(open('work/all-university-completion-20261012/fetch-fifth-a.py').read().split('with concurrent.futures.ThreadPoolExecutor')[0])
sources={'hansei-micro.pdf':'https://www.hansei.ac.kr/cmm/file/downFile.do?prgrmFileId=i6K5mSt7cRg9SDitfUncKQ&prgrmFileSn=0','hansei-curriculum-new':'https://www.hansei.ac.kr/view.do?no=10226','dgist-college-new':'https://www.dgist.ac.kr/college/'}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-eighth.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
