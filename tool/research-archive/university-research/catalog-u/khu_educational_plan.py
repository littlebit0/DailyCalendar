"""Educational table extraction; no raw contact or hidden staff fields retained."""
import re
from html import escape
from lxml import html
allowed={'기본정보','선수과목','수업개요 및 목표','수업운영방식','수업유형 및 방법','교재 및 참고자료','평가방법','주별강의내용'}
basic={'강좌명','교강사명','학수번호','이수구분','개설학과','학점','강의시간강의실','영어강좌여부','성적기록방법'}
known=set('html head body title meta link div p span h1 h2 h3 h4 h5 h6 table thead tbody tfoot tr th td colgroup col br b strong em i u a ul ol li input button form label select option hr img script style noscript font center blockquote'.split())
def clean_text(value):
 value=re.sub(r'\s+',' ',value).strip()
 value=re.sub(r'https?://[^\s<>]+','[외부 링크 생략]',value)
 value=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[연락처 생략]',value)
 value=re.sub(r'(?<!\d)(?:0\d{1,2})[- .]\d{3,4}[- .]\d{4}(?!\d)','[연락처 생략]',value)
 return value

def educational_page(body):
 body=re.sub(r'<!--.*?-->','',body,flags=re.S)
 body=re.sub(r'<(script|style)\b[^>]*>.*?</\1\s*>','',body,flags=re.S|re.I)
 def protect(match):
  name=re.match(r'</?([A-Za-z0-9_-]+)',match.group())
  return match.group() if name and name[1].lower() in known else escape(match.group())
 body=re.sub(r'</?[^>\n]+>',protect,body)
 doc=html.fromstring(body);headers=[clean_text(h.text_content()) for h in doc.xpath('//h1')];out=[]
 for h in doc.xpath('//h2'):
  title=clean_text(h.text_content())
  if title not in allowed:continue
  tables=[]
  for sibling in h.itersiblings():
   if sibling.tag=='h2':break
   if sibling.tag=='table':tables.append(sibling)
  if not tables:continue
  rows=[]
  for tr in [tr for table in tables for tr in table.xpath('.//tr')]:
   cells=[clean_text(c.text_content()) for c in tr.xpath('./th|./td')]
   if title=='기본정보':
    pairs=[]
    for i in range(0,len(cells)-1,2):
     if cells[i] in basic:pairs.extend(cells[i:i+2])
    cells=pairs
   if cells:rows.append(cells)
  out.append({'section':title,'rows':rows})
 return headers,out

