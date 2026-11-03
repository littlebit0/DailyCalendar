import requests,pathlib,concurrent.futures,json
P=pathlib.Path(__file__).parent
def run(m):
 u=f'https://eulji.ac.kr/renewal/index.html?menuno=8069&calendar_no=105&year=2026&month={m}';r=requests.get(u,headers={'User-Agent':'Mozilla/5.0','Accept':'text/html'},timeout=25);P.joinpath(f'eulji-cal-{m+1:02}.html').write_bytes(r.content);return {'month':m+1,'url':u,'status':r.status_code,'bytes':len(r.content)}
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as ex:r=list(ex.map(run,range(12)))
(P/'eulji-calendar-acquisition.json').write_text(json.dumps(r,indent=2));print([(x['month'],x['status'],x['bytes'])for x in r])
