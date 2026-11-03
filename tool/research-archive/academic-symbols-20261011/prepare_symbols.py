from PIL import Image,ImageChops
import pathlib,json,hashlib
root=pathlib.Path('work/academic-symbols-20261011'); old=json.load(open('assets/academic/university_logo_sources.json')); downloads=json.load(open(root/'mark-downloads.json'));official=json.load(open(root/'official/images.json'))
# Reviewed separate graphic bounds, in source-relative coordinates. No redrawing.
crops={'0000147':(0,0,1,.78),'0000260':(0,.22,1,1),'0000046':(0,0,1,.65),'0000060':(0,0,1,.58),'0000010':(0,0,1,.52),'0000245':(0,0,1,.80),'0000082':(0,0,1,.55),'0000087':(0,0,1,.78),'0000100':(.67,0,1,1),'0000116':(0,0,1,.58),'0000121':(0,0,1,.66),'0000136':(0,0,1,.64),'0000243':(0,0,.36,1),'0000142':(0,0,1,.51),'0000143':(0,0,1,.59),'0002712':(0,0,1,.76),'0000156':(0,0,1,.66),'0000240':(0,0,1,.56),'0000179':(0,0,1,.61),'0000246':(.54,0,1,1),'0000181':(0,0,.27,1),'0000030':(0,0,1,.71),'0000037':(0,0,1,.68),'0000247':(0,0,1,.61),'0000189':(0,0,1,.72),'0000197':(0,0,1,.68),'0000233':(0,0,1,.67)}
overrides={'0000003':'kangwon-symbol','0000381':'gist-symbol','0000250':'unist-emblem','0000374':'kaist-emblem','0000273':'knou-logo','0003022':'nuch-mark','0000254':'pue-mark','0000144':'silla-crest','11d7e932cd189d28':'ssit-ci','0000246':'chodang-mark'}
entries={}
for key,previous in old['logos'].items():
 ident=key.split(':')[-1];entry={'name':previous['name'],'asset':previous.get('asset','assets/academic/logos/'+key.replace(':','-')+'.png')}
 if ident=='0000288':
  pathlib.Path(previous.get('asset','assets/academic/logos/'+key.replace(':','-')+'.png')).unlink(missing_ok=True);entries[key]={'name':previous['name'],'status':'unavailable','reason':'Actual university mark not acquired; user approved no logo pending original. No corporate substitution.'};continue
 crop=None
 if ident=='0003139':
  im=Image.open(root/'official/kentech/Emblem.jpg').convert('RGBA');entry['url']=official['kentech-zip']['url'];crop=(0,0,1,.55)
 elif ident in overrides:
  v=official[overrides[ident]];im=Image.open(v['raw']).convert('RGBA');entry['url']=v['url']
  if ident=='0000374':crop=(0,0,.5,1)
  elif ident=='0000273':crop=(0,0,.255,1)
  elif ident=='0003022':crop=(.20,0,.78,.71)
  elif ident=='0000254':crop=(0,0,.13,.36)
  elif ident=='0000246':crop=(5/730,399/470,38/730,450/470)
  elif ident=='11d7e932cd189d28':crop=(0,0,.263,1)
 elif ident=='0000007':
  im=Image.open('work/academic-region-logos-20261011/institution-academyinfo-0000007.raw').convert('RGBA');entry['url']=previous['url']
 elif ident in ['0000382','0000184','0000383','knpu']:
  # Verified standalone school marks already sourced in the preceding acquisition.
  im=Image.open(previous.get('asset','assets/academic/logos/'+key.replace(':','-')+'.png')).convert('RGBA');entry['url']=previous['url'];entry['identityNote']=previous.get('identityNote','Existing actual school graphic')
 else:
  v=downloads[key];assert 'ico_uni' not in v['url'];im=Image.open(v['raw']).convert('RGBA');entry['url']=v['url'];entry['sourcePage']=v['page'];crop=crops.get(ident)
 if crop:
  crop=tuple(round(c*(im.width if i%2==0 else im.height)) for i,c in enumerate(crop));im=im.crop(crop);entry['sourceCropPixels']=list(crop)
 if ident=='0003139':
  mask=im.convert('RGB').point(lambda x:x)
  # The official sheet includes headings; select the blue first emblem only.
  pix=im.load();pts=[(x,y) for y in range(im.height) for x in range(im.width) if pix[x,y][2]>pix[x,y][0]*1.5 and pix[x,y][0]<100 and pix[x,y][2]>80]
  assert pts;im=im.crop((min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1))
 # Remove only blank outer padding; graphic colours and internal lettering stay intact.
 white=Image.new('RGBA',im.size,'white');flat=Image.alpha_composite(white,im).convert('RGB');diff=ImageChops.difference(flat,Image.new('RGB',im.size,'white'));box=diff.convert('L').point(lambda x:255 if x>12 else 0).getbbox()
 if ident=='11d7e932cd189d28':box=im.getchannel('A').getbbox()
 if box:im=im.crop(box)
 im.thumbnail((192,192),Image.Resampling.LANCZOS);im.save(entry['asset']);entry['sha256']=hashlib.sha256(pathlib.Path(entry['asset']).read_bytes()).hexdigest();entry['size']=list(im.size);entry['presentation']='standalone school symbol or crest; attached university name excluded';entries[key]=entry
old['logos']=entries;old['presentationPolicy']='Separate school-name text excluded; lettering originally inside a crest allowed. White rounded tile. Jungseok intentionally has no logo pending authentic original.'
pathlib.Path('assets/academic/university_logo_sources.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
# Full asset review sheet.
o=Image.new('RGB',(1000,((len(entries)+9)//10)*95),'#ddd')
from PIL import ImageDraw
d=ImageDraw.Draw(o)
for i,(key,v) in enumerate(entries.items()):
 x=i%10*100;y=i//10*95
 if 'asset' in v:
  im=Image.open(v['asset']).convert('RGBA');im.thumbnail((70,65));o.paste(Image.new('RGB',(75,68),'white'),(x,y));o.paste(im,(x+(75-im.width)//2,y+(68-im.height)//2),im)
 d.text((x,y+70),key.split(':')[-1][:10],fill='black')
o.save(root/'prepared-review.png');print('Prepared',sum('asset' in v for v in entries.values()),'school marks; Jungseok explicitly unavailable')
