import re,html,sys
def text(p):
  s=open(p,encoding='utf-8',errors='replace').read()
  t=re.sub(r'<script.*?</script>|<style.*?</style>','',s,flags=re.S); t=re.sub(r'<[^>]+>',' ',t); t=html.unescape(re.sub(r'\s+',' ',t))
  i=t.find('hufs_sub_notitle')
  return t[i:] if i>=0 else t
if __name__=='__main__':
  for p in sys.argv[1:]:
    t=text(p); open(p.replace('.html','.txt'),'w').write(t)
    m=re.search(r'학과소개(.{0,600})',t)
    print('=='+p, t[17:40], '|', m.group(1)[:500] if m else '')
