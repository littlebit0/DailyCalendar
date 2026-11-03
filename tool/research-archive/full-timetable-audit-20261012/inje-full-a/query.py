from lxml import html
from pathlib import Path
import urllib.parse,subprocess,json
p=Path(__file__).parent;s=html.parse(str(p/'navi-lecture.html'));data={}
for n in s.xpath('//input[@name]'):
 if n.get('type','').lower() not in ['checkbox','radio','submit']:data[n.get('name')]=n.get('value','')
for n in s.xpath('//select[@name]'):
 opts=n.xpath('./option[@selected]') or n.xpath('./option');data[n.get('name')]=opts[0].get('value','') if opts else ''
data['__EVENTTARGET']='ctl00$mainContent$btn조회';data['__EVENTARGUMENT']=''
(p/'navi-query-form.txt').write_text(urllib.parse.urlencode(data))
r=subprocess.run(['curl','-L','--max-time','25','-sS','--data-binary','@'+str(p/'navi-query-form.txt'),'-o',str(p/'navi-query-all.html'),'-w','%{http_code} %{url_effective}','https://navi.inje.ac.kr/AllUsers/Lecture.aspx'],capture_output=True,text=True)
print(r.stdout,r.stderr)
s=html.parse(str(p/'navi-query-all.html'));print(' '.join(s.getroot().text_content().split())[-11000:])
