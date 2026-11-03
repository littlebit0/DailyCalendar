import re,html,sys
t=open(sys.argv[1],encoding='utf-8',errors='replace').read()
t=re.sub(r'<(script|style)[^>]*>.*?</\1>','',t,flags=re.S)
t=re.sub(r'<br\s*/?>|</p>|</div>|</tr>|</li>','\n',t)
t=html.unescape(re.sub(r'<[^>]+>','',t))
t=re.sub(r'[ \t\r\xa0]+',' ',t); t=re.sub(r'\n\s*\n+','\n',t)
open(sys.argv[2],'w').write(t); print(sys.argv[2],len(t))
