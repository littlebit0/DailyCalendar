from PIL import Image,ImageDraw
import pathlib,json
ids='0000046 0000003 0000060 0000069 0000010 0000245 0000082 0000087 0000100 0000116 0000121 0000136 0000243 0000142 0000143 0002712 0000156 0000240 0000179 0000246 0000181 0000030 0000037 0000247 0000189 0000197 0000233'.split()
root=pathlib.Path('work/academic-symbols-20261011');j=json.load(open(root/'mark-downloads.json'))
out=Image.new('RGB',(1000,((len(ids)+4)//5)*180),'#ddd');d=ImageDraw.Draw(out)
for i,k in enumerate(ids):
 im=Image.open(root/'marks'/(k+'.raw')).convert('RGBA');im.thumbnail((185,145));x=(i%5)*200;y=(i//5)*180;out.paste(im,(x+(190-im.width)//2,y),im);d.text((x+5,y+150),k,fill='black')
out.save(root/'detail-sheet.png')
