import pathlib,urllib.request,concurrent.futures,re,html
P=pathlib.Path(__file__).parent
SOURCES={
 'kumoh-current-registration':'https://edu.kumoh.ac.kr/ko/sub06_01_01_01.do?articleNo=572943&mode=view',
 'kunsan-current-coursebook':'https://www.kunsan.ac.kr/board/view.kunsan?boardId=BBS_0000009&dataSid=1384672&menuCd=DOM_000000105001002000&paging=ok&searchType=DATA_TITLE&startPage=1',
 'mokpo-current-registration':'https://mnusdm.mokpo.ac.kr/law/7398/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGbGF3JTJGMzI1JTJGMjg1MTA3JTJGYXJ0Y2xWaWV3LmRvJTNG'}
def one(k,u):
 try:
  with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25) as resp:b=resp.read()
  s=b.decode('utf-8',errors='replace');(P/(k+'.html')).write_text(s)
  result=[]
  for a in re.findall(r'<a\b[^>]*>.*?</a>',s,re.S):
   if any(w in a for w in ['다운로드','download','attach','첨부','편람','개설과목','강의시간표','수업시간표']):result.append(a[:850])
  return k,len(b),result[-15:]
 except Exception as e:return k,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for r in pool.map(lambda z:one(*z),SOURCES.items()):print(r)
