"""Join actual PDF operator text; never crop long titles into neighboring codes."""
import json,pathlib,re
R=pathlib.Path(__file__).resolve().parent
native=json.loads((R/'kyonggi-public-coordinate-fixture.json').read_text());parsed=json.loads((R/'kyonggi-current-public-education-tables-20261008.json').read_text())
by={(r['sourcePDF'],r['page'],r['registrationNumber']):r for r in parsed['rows']};out=[]
for doc in native:
 general=doc['file'].endswith('교양.pdf')
 bounds=[(150,400,'classification'),(400,1400,'title'),(1400,1650,'courseCode'),(1650,1790,'credits'),(1790,2000,'hours'),(2000,2170,'year')] if general else [(150,1110,'title'),(1110,1400,'courseCode'),(1400,1500,'credits'),(1500,1740,'hours'),(1740,1970,'classification'),(1970,2170,'year')]
 bounds += [(2350,2970,'professor'),(2970,3100,'weekday'),(3100,3550,'period'),(3550,4200,'classroom'),(4200,6000,'remarks')]
 box_text={}
 for page in doc['rows']:
  anchors=[x for x in page['cells'] if 2170<=x['x']<2350 and re.fullmatch(r'\d{4}',x['text'])]
  anchors.sort(key=lambda x:x['y'])
  for i,a in enumerate(anchors):
   row=by[(doc['file'],page['page'],a['text'])];end=anchors[i+1]['y'] if i+1<len(anchors) else 999999
   fields={}
   for left,right,name in bounds:
    cells=[x for x in page['cells'] if a['y']<=x['y']<end and left<=x['x']<right]
    lines={}
    for x in cells:lines.setdefault(x['y'],[]).append(x)
    fields[name]='\n'.join(''.join(z['text'] for z in sorted(values,key=lambda z:z['x'])) for _,values in sorted(lines.items()))
   colmap={'classification':0 if general else 4,'title':1 if general else 0,'courseCode':2 if general else 1,'credits':3 if general else 2,'hours':4 if general else 3,'year':5,'professor':7,'weekday':8,'period':9,'classroom':10,'remarks':11}
   for name,col in colmap.items():
    cell=row['cells'][col];box=tuple(cell['bbox']) if cell.get('bbox') else None
    if fields[name] and box:box_text[(page['page'],col,box)]=fields[name]
    elif box and cell.get('mergedCellEnclosesActualRow'):
     fields[name]=box_text.get((page['page'],col,box),'')
   for name in fields:
    if not fields[name] and name not in ['classroom','remarks']:
     fields[name]=row['educationalFields'].get(name,'')
   time_anchors=[z for z in page['cells'] if a['y']<=z['y']<end and 2970<=z['x']<3100 and z['text'] in '월화수목금토일' and len(z['text'])==1]
   time_anchors.sort(key=lambda z:z['y']);time_rows=[]
   for ti,z in enumerate(time_anchors):
    stop=time_anchors[ti+1]['y'] if ti+1<len(time_anchors) else end
    item={'weekday':z['text'],'operatorBaseline':z['y']}
    for left,right,name in [(3100,3550,'period'),(3550,4200,'classroom')]:
     grouped={}
     for cell in page['cells']:
      if z['y']<=cell['y']<stop and left<=cell['x']<right:grouped.setdefault(cell['y'],[]).append(cell)
     item[name]='\n'.join(''.join(q['text'] for q in sorted(v,key=lambda q:q['x'])) for _,v in sorted(grouped.items()))
    time_rows.append(item)
   row['nativeTimeRows']=time_rows
   row['rawOperatorEducationalFields']=fields;row['operatorRegistrationBaseline']=a['y'];out.append(row)
assert len(out)==1640 and len({x['registrationNumber'] for x in out})==1640
valid=sum(bool(re.fullmatch(r'[A-Z]{2,4}\d{3,4}',x['rawOperatorEducationalFields']['courseCode'])) for x in out)
(R/'kyonggi-native-education-recovered-20261008.json').write_text(json.dumps({'researchOnly':True,'offeringCount':1640,'actualSubjectCodeValidCount':valid,'rawOperatorTextPreserved':True,'rows':out},ensure_ascii=False,indent=2)+'\n');print('rows1640 actualcode',valid)
