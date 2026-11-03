"""Keep complete education clauses; headings distinct from inline references."""
import urllib.request,pathlib,json,re,sys
R=pathlib.Path(__file__).resolve().parent
context=(R/'collect_hknu_current_operating_context_20261008.py').read_text();exec(context[:context.index('records=[]')])
url='https://cedu.hknu.ac.kr/cedu/intro/board.do'
with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:
 assert response.status==200;body=response.read(2000000).decode('utf8')
p=Text();p.feed(body);text='\n'.join(x.strip() for x in ''.join(p.parts).splitlines() if x.strip());parts=[]
for num in [2,3,4,7,8,9,13]:
 pattern=r'^제'+str(num)+r'조\([\s\S]*?(?=^제\d+조(?:의\d+)?\(|^\[별표\d+\]|\Z)';m=re.search(pattern,text,re.M);assert m,num;parts.append(m.group(0).strip())
for num in [1,2]:
 m=re.search(r'^\[별표'+str(num)+r'\][\s\S]*?(?=^\[별표\d+\]|\Z)',text,re.M);assert m,num;parts.append(m.group(0).strip())
safe,masked,removed=filter_education('\n\n'.join(parts));assert '70% 미만' in safe and '동영상' in safe
path=R/'hknu-current-operating-guidance-20261008.json';data=json.loads(path.read_text());rec=data['records'][1];rec['educationalOperatingText']=safe;rec['maskedPrivateTokens']=masked;rec['privateLinesRemoved']=removed;rec['scope']='complete actual education operation clauses2/3/4/7/8/9/13 and actual appendix1/2 headings only, not inline references';path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print('complete education clauses',len(safe))
