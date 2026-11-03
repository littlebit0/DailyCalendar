"""Research-only extraction of actual coordinates; no generated course identities."""
import json,re
from pathlib import Path
ROOT=Path(__file__).parent

def extract(source):
    cells={(c['row'],c['column']):c['value'] for c in source['nonemptyCells']}
    headers=sorted(r for (r,c),v in cells.items() if c==2 and v=='Crs. No.')
    slots=[];unknown=[]
    for row in headers:
        header=max(r for r in range(row+1) if (r,1) in cells and r>=3)
        raw_header=cells[header,1]
        base=re.search(r'(\d{1,2}):(\d{2})\s*[~-]\s*(\d{1,2}):(\d{2})',raw_header)
        if not base:raise ValueError(('Invalid time header',header,raw_header))
        for column in range(3,83):
            raw=cells.get((row,column))
            if not raw:continue
            title=str(cells.get((row+2,column),''));teacher=str(cells.get((row+1,column),''))
            room=str(cells.get((row+4,column),''))
            if not title:
                unknown.append({'row':row,'column':column,'rawCode':raw,'unparsed':'merged/non-course cell without independent title'})
                continue
            code_pattern=r'\b([A-Z]{2}\d{4})(?:-(\d+(?:[,/]\d+)*))?'
            codes=re.findall(code_pattern,str(raw))
            residue=re.sub(code_pattern,'',str(raw))
            residue=re.sub(r'Rec\.?|[\s()/]', '',residue)
            if not codes or residue:unknown.append({'row':row,'column':column,'rawCode':raw,'unparsed':residue})
            section=re.search(r'분반\s*(\d+)|(\d+)\s*분반|\((\d+)반\)',title)
            title_section=next((v for v in section.groups() if v),None) if section else None
            identities=[]
            for code,part in codes:
                for section_value in re.split(r'[,/]',part) if part else [title_section]:
                    identities.append({'code':code,'publishedSection':section_value,'sectionSource':'code' if part else 'title' if title_section else 'unpublished'})
            clocks=re.findall(r'(\d{1,2}):(\d{2})\s*[~-]\s*(\d{1,2}):(\d{2})',title)
            hour_clocks=re.findall(r'(\d{1,2})시\s*[~～-]\s*(\d{1,2})시',title)
            end_only=re.search(r'\(\s*[~～]\s*(\d{1,2}):(\d{2})\s*\)',title)
            clock=clocks[0] if len(clocks)==1 else (hour_clocks[0][0],'00',hour_clocks[0][1],'00') if len(hour_clocks)==1 else base.groups()
            if end_only:
                clock=(clock[0],clock[1],end_only.group(1),end_only.group(2))
            start=int(clock[0])*60+int(clock[1]);end=int(clock[2])*60+int(clock[3])
            if not 0<=start<end<=1440:raise ValueError(('Bad actual clock',title,clock))
            weekday=1 if column<19 else 2 if column<40 else 3 if column<56 else 4 if column<76 else 5
            title_weekday=re.search(r'(?:주1회\s*|\()([월화수목금토일])(?:요일)?\s*[:：]?\s*\d{1,2}:\d{2}',title)
            if title_weekday:
                weekday='월화수목금토일'.index(title_weekday.group(1))+1
            slots.append({'row':row,'column':column,'weekday':weekday,'rawCode':raw,'identities':identities,
              'title':title,'professor':teacher,'classroom':room,'publishedClock':{'startMinute':start,'endMinute':end},
              'clockSource':'title' if len(clocks)==1 or len(hour_clocks)==1 or end_only else 'header','multipleTitleClocks':clocks if len(clocks)>1 else [],
              'deliveryUnverified':'MOOC' in title,'recitation':'Rec' in str(raw) or '연습' in title})
    return slots,unknown

if __name__=='__main__':
    source=json.loads((ROOT/'gist-whole-coordinate-fixture.json').read_text())
    slots,unknown=extract(source)
    result={'researchOnly':True,'completionClaim':False,'sourceUrl':source['sourceUrl'],'sha256':source['sha256'],
      'slots':slots,'unparsedCodeCells':unknown,'remainingEvidence':['all current actual sections/credits/classifications','MOOC attendance','graduate/alias scope','latest closure/change','ordinary semester bounds']}
    (ROOT/'gist-current-slot-research.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Actual grid slots',len(slots),'unparsed code cells',len(unknown),'unpublished section aliases',sum(i['publishedSection'] is None for s in slots for i in s['identities']))
