"""Official published current complete undergraduate workbook only; no login."""
import urllib.request,pathlib,re,html,json,io,collections
import openpyxl
P=pathlib.Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
URL='https://www.kw.ac.kr/ko/life/bachelor_info13.jsp'
def fetch(url):
 return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':UA,'Referer':URL}),timeout=30).read()
def main():
 page=fetch(URL).decode('utf8');(P/'kw-public-timetable.html').write_text(page)
 section=page.split('학부 강의시간표',1)[1].split('강의시간표 포함 정보',1)[0]
 m=re.search(r'href="([^"]+)"[^>]*[^<]*>2026학년도 2학기',section)
 if not m:raise ValueError('Official current term workbook link absent')
 download=html.unescape(m[1]);data=fetch(download);(P/'kw-2026-2-timetable.bin').write_bytes(data)
 workbook=openpyxl.load_workbook(io.BytesIO(data),data_only=True);sheet=workbook['강의시간표'];headers=list(next(sheet.iter_rows(min_row=3,max_row=3,values_only=True)))
 rows=[dict(zip([str(i)+':'+str(h)for i,h in enumerate(headers)],r))for r in sheet.iter_rows(min_row=5,values_only=True)if r[6]]
 ids=[r['6:학정번호']for r in rows]
 if len(ids)!=len(set(ids)):raise ValueError('Duplicate class IDs')
 (P/'kw-all-2026-2.json').write_text(json.dumps({'headers':headers,'records':rows},ensure_ascii=False,indent=2))
 print({'records':len(rows),'uniqueIds':len(set(ids)),'source':download})
if __name__=='__main__':main()
