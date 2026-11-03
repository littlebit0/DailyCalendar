import re,ast
from pathlib import Path
p=Path(__file__).parent
rx=re.compile(r"\}\('((?:\\.|[^'\\])*)',(\d+),(\d+),'((?:\\.|[^'\\])*)'\.split\('\|'\),0,\{\}\)\)")
def word(n,b):
 chars='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';s=''
 while n:s=chars[n%b]+s;n//=b
 return s or '0'
for n in ['hanyang-commonlibrary.js','hanyang-communicator.js','hanyang-controller.js']:
 s=(p/n).read_text()
 for _ in range(3):
  m=rx.search(s)
  if not m:break
  payload=ast.literal_eval("'"+m[1]+"'"); ks=ast.literal_eval("'"+m[4]+"'").split('|');base=int(m[2]);count=int(m[3]);mapping={word(i,base):ks[i] for i in range(min(count,len(ks))) if ks[i]}
  s=re.sub(r'\b\w+\b',lambda q:mapping.get(q[0],q[0]),payload)
 (p/n.replace('.js','-readable.js')).write_text(s)
 print(n,len(s), 'eval(function' in s)
