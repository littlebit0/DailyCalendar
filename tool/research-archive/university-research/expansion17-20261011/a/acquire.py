import urllib.request,pathlib,concurrent.futures,json
BASE=pathlib.Path(__file__).parent
URLS={'hongik-form':'https://cn.hongik.ac.kr/app/timetable/hak03.jsp','hongik-home':'https://www.hongik.ac.kr/kr/main.do','ewha-time':'https://www.ewha.ac.kr/ewha/bachelor/timetable.do','iccu-cal':'https://www.iccu.ac.kr/hq/php/schedule_a.php','inje-cal':'https://www.inje.ac.kr/kor/setRoute/B_Page.asp?pCode=IF010010000&viewType=vy','wsu-time':'https://slas.wsu.ac.kr/board/read.jsp?code=slas0401&id=268330','eulji-cal':'https://www.eulji.ac.kr/?menuno=3014','iccu-nursing':'https://nursing.iccu.ac.kr/community/notice.php?page=4'}
def get(kv):
 k,v=kv
 try:
  r=urllib.request.urlopen(v,timeout=25);b=r.read();BASE.joinpath(k+'.html').write_bytes(b);return {'key':k,'url':v,'final':r.url,'status':r.status,'bytes':len(b)}
 except Exception as e:return {'key':k,'url':v,'error':str(e)}
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex: rows=list(ex.map(get,URLS.items()))
 BASE.joinpath('acquisition.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)); print(json.dumps(rows,ensure_ascii=False,indent=2))
