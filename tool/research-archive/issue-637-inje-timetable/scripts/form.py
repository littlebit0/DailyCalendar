import re,sys,html,urllib.parse
t=open(sys.argv[1],encoding='utf-8').read()
def attrs(s): return {k.lower():html.unescape(v) for k,v in re.findall(r'(\w[\w-]*)\s*=\s*"([^"]*)"',s)}
data={}
for m in re.finditer(r'<input\b([^>]*)>',t,re.I):
  a=attrs(m.group(1))
  if 'name' in a and a.get('type','').lower() not in ('checkbox','radio','submit','button','image'): data[a['name']]=a.get('value','')
for m in re.finditer(r'<select\b([^>]*)>(.*?)</select>',t,re.I|re.S):
  a=attrs(m.group(1)); opts=re.findall(r'<option\b([^>]*)>(.*?)</option>',m.group(2),re.S)
  sel=[o for o in opts if 'selected' in o[0]] or opts
  v=attrs(sel[0][0]).get('value','') if sel else ''
  data[a['name']]=v
  print('SELECT',a['name'],[(attrs(o[0]).get('value'),re.sub('<[^>]+>','',o[1]).strip(),'selected' in o[0]) for o in opts][:15],file=sys.stderr)
data['__EVENTTARGET']='ctl00$mainContent$btn조회';data['__EVENTARGUMENT']=''
open(sys.argv[2],'w').write(urllib.parse.urlencode(data))
