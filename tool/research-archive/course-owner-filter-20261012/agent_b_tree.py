from html.parser import HTMLParser
import re,json,collections
from pathlib import Path
root=Path('work/course-owner-filter-20261012')
class Node:
 def __init__(self,tag,parent=None,attrs=None):self.tag=tag;self.parent=parent;self.children=[];self.data='';self.attrs=dict(attrs or [])
 def text(self):return self.data+''.join(c.text() for c in self.children)
 def anchors(self):return ([self] if self.tag=='a' else [])+[a for c in self.children for a in c.anchors()]
class Parser(HTMLParser):
 def __init__(self,s):super().__init__();self.root=Node('root');self.stack=[self.root];self.nodes=[];self.feed(s)
 def handle_starttag(self,tag,attrs):
  n=Node(tag,self.stack[-1],attrs);self.stack[-1].children.append(n);self.nodes.append(n)
  if tag not in ['img','input','br','hr','meta','link','source','area','wbr']:self.stack.append(n)
 def handle_endtag(self,tag):
  for i in range(len(self.stack)-1,0,-1):
   if self.stack[i].tag==tag:self.stack=self.stack[:i];break
 def handle_data(self,data):self.stack[-1].data+=data
out={}
for p in root.glob('*official-home.html'):
 u=p.name.split('-')[0];parser=Parser(p.read_text());records=[]
 for n in parser.nodes:
  if n.tag!='a':continue
  label=re.sub(r'\s+',' ',n.text()).strip();anc=n.parent
  if not label or len(label)>80:continue
  while anc:
   if anc.tag=='li':
    anchors=anc.anchors(); name=re.sub(r'\s+',' ',anchors[0].text()).strip() if anchors else ''
    if name!=label and name.endswith('대학') and name not in ['대학','대학/대학원']:
     records.append(dict(college=name,department=label,href=n.attrs.get('href')));break
   anc=anc.parent
 out[u]=records
 print(u,len(records),records[:3])
(root/'agent-b-menu-hierarchy.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
