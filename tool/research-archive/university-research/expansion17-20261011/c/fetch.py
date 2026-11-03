import urllib.request,concurrent.futures,pathlib
p=pathlib.Path(__file__).parent
urls={'nambu-timetable-notice':'https://www.nambu.ac.kr/board/NAMBU_BOARD_0002/boardView.do?bdId=BD_00000000000110415&menuCd=KR006006002','dju-calendar':'https://www.dju.ac.kr/dju/sv/schdulView/schdulCalendarView.do?mi=1166','dju-notices':'https://www.dju.ac.kr/dju/main.do','kangnam-calendar':'https://web.kangnam.ac.kr/menu/02be162adc07170ec7ee034097d627e9.do','kangnam-timetable':'https://app.kangnam.ac.kr/knumis/sb/sbm1050DownloadAll.jsp?schl_smst=2&schl_year=2026'}
def get(k,u):
 try:
  r=urllib.request.urlopen(u,timeout=30);b=r.read();(p/(k+'.html')).write_bytes(b);return k,r.status,len(b),r.headers.get('Content-Type')
 except Exception as e:return k,str(e)
print(list(concurrent.futures.ThreadPoolExecutor(5).map(lambda kv:get(*kv),urls.items())))
