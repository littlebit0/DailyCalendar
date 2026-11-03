import re,sys,html
n=sys.argv[1]
t=open(n+'.html',encoding='utf-8',errors='replace').read()
t=re.sub(r'(?s)<(script|style).*?</\1>','',t)
t=re.sub(r'<br\s*/?>|</p>|</div>|</tr>|</li>|</h\d>','\n',t)
t=html.unescape(re.sub(r'<[^>]+>','',t))
t=re.sub(r'[ \t\xa0]+',' ',t); t=re.sub(r'\n\s*\n+','\n',t)
open(n+'.txt','w').write(t); print(n,len(t))
