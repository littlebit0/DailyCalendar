#!/usr/bin/env python3
"""Extract the verified 180-page September2026 Yongin official publication.

Preserves merged identity cells and timetable continuation rows. This deliberately
rejects another document layout/year instead of returning partial course data.
Uses installed pdfplumber/pypdfium2; no networking or new dependency installation.
"""
import argparse
import json
from pathlib import Path
import re


def clean_note(value):
    # A page may place another timetable header between successive identities.
    # Its heading/column labels are layout, not the current course's restriction.
    value=re.sub(r'\n\[교양\d+영역 원격수업 교과목\]\s*\n학년\s+이수\s*\n구분\s+학수번호.*', '', value, flags=re.S)
    value=re.sub(r'\n학년\s+이수\s*\n구분\s+(?:수강대상\s+)?학수번호.*', '', value, flags=re.S)
    value=re.sub(r'\n[\d·]+\s+(?:교필|교선|전공|기전|교직)[^\n]*\Z', '', value)
    return value.strip()


def extract_records(T,PAGES):
    records=[];continuation_count=0
    for t in T:
     if not 98<=t['page']<=178:continue
     hi=next((i for i,r in enumerate(t['rows'][:3]) if any(re.sub(r'\s+','',x or '')=='학수번호' for x in r)),None)
     if hi is None:continue
     header=[re.sub(r'\s+','',x or '') for x in t['rows'][hi]]
     ci=header.index('학수번호'); last=None;lastroom='';target=''
     page=PAGES[t['page']-1]
     title=next(line.strip() for line in page.strip().splitlines() if not re.fullmatch(r'-\s*\d+\s*-',line.strip()))
     if '학년' in title:raise ValueError(f'No page title {t["page"]}: {title}')
     course_positions=list(re.finditer(r'[A-Z0-9]{6}-\d{2}',page))
     notes={}
     for i,m in enumerate(course_positions):
      end=course_positions[i+1].start() if i+1<len(course_positions) else len(page)
      chunk=page[m.end():end];star=chunk.find('*')
      notes[m[0]]=clean_note(chunk[star:]) if star>=0 else ''
     for row in t['rows'][hi+1:]:
      if len(row)!=len(header):raise ValueError('Row width')
      code=(row[ci]or'').strip()
      identity=re.match(r'([A-Z0-9]{6}-\d{2})(?:\s|$)',code)
      if identity:
       code=identity[1]
       name=row[ci+1] or row[ci][identity.end():].split('*',1)[0].strip()
       if '수강대상' in header:target=row[2]or target
       lastroom='';last={'page':t['page'],'department':title,'codeSection':code,'name':name,
       'creditsCapacity':row[ci+2],'classification':row[1],'grade':row[0], 'target':target,
       'professors':[], 'meetings':[], 'notes':notes.get(code,''), 'sourceRows':[]}
       records.append(last)
      elif not any(row):continue
      elif last is None:raise ValueError(f'Orphan continuation {t["page"]}: {row}')
      else:continuation_count+=1
      last['sourceRows'].append(row)
      # A continuation can contain an extra professor and extra real meeting.
      teacher=row[ci+3]
      if teacher and teacher not in last['professors']:last['professors'].append(teacher)
      if '강의시간' in header:
       time=row[header.index('강의시간')]or'';room=row[header.index('강의실')]or lastroom
       lastroom=room
       if time:last['meetings'].append({'rawTime':time,'rawRoom':room})
      elif row[-1]:last['notes']+='\n'+row[-1]
    # Consortium table is separate from own remote courses (own21 also in core).
    remote=[]
    text='\n'.join(PAGES[89:91])
    pattern=re.compile(r'(\d+)\s+(교양선택\s*\(4영역\)|일반선택)\s+(W\d{5}[A-Z]\d{2})\s+(.*?)(?=\n\d+\s+(?:교양선택|일반선택)|\Z)',re.S)
    for m in pattern.finditer(text):
     chunk=m[4];credit=re.search(r'\s+([1-9])\s+(\d+)\s+(\S+)\s+',chunk)
     if not credit:raise ValueError('Remote credits missing')
     name=chunk[:credit.start()].strip();note=''
     if '＊' in name:name,note=name.split('＊',1)
     remote.append({'sequence':int(m[1]),'rawCode':m[3],'name':re.sub(r'\s+','',name),
     'classification':re.sub(r'\s+','',m[2]),'credits':int(credit[1]),'professor':credit[3],
     'notes':note+'\n'+chunk[credit.end():].strip(),'department':'OCU 컨소시엄'})
    if [x['sequence'] for x in remote]!=list(range(1,22)):raise ValueError('Incomplete OCU21')
    for t in T:
     if t['page']==94:
      r=t['rows'][1];remote.append({'rawCode':r[1],'name':r[2],'classification':re.sub(r'\s+','',r[0]),'credits':int(r[3]),'professor':r[5],'notes':'소속대학: '+r[6],'department':'KCU 컨소시엄'})
    for record in records:record['notes']=clean_note(record['notes'])
    if len(records)!=953 or len(remote)!=22:raise ValueError("Incomplete verified 2026-2 Yongin publication")
    return {"academicYear":2026,"semester":"2","records":records,"remote":remote,"continuationRowCount":continuation_count}


def extract_table_rows(page,table):
    rows=table.extract()
    header_index=next((i for i,r in enumerate(rows[:3]) if '학수번호' in [re.sub(r'\s+','',v or '') for v in r]),None)
    if header_index is not None:
        header=[re.sub(r'\s+','',v or '') for v in rows[header_index]]
        if '강의실' in header:
            column=header.index('강의실')
            identity_column=header.index('학수번호')
            time_column=header.index('강의시간')
            previous_cell=None;previous_value=None
            for i in range(header_index+1,len(rows)):
                cells=table.rows[i].cells
                cell=cells[column]
                if cell is not None:
                    previous_cell,previous_value=cell,rows[i][column]
                elif previous_cell is not None:
                    anchor=cells[identity_column] or cells[time_column]
                    if anchor is not None:
                        center=(anchor[1]+anchor[3])/2
                        # Only an actual PDF rectangle spanning
                        # this row proves inherited room text.
                        if previous_cell[1] <= center <= previous_cell[3]:
                            rows[i][column]=previous_value
                        else:
                            # Some PDF updates omit right-column
                            # grid segments while printing room
                            # text. Read only that exact column
                            # at the current real clock row.
                            clock_anchor=cells[time_column] or anchor
                            bounds=table.rows[header_index].cells[column]
                            if bounds is not None:
                                region=page.crop((bounds[0],clock_anchor[1],bounds[2],clock_anchor[3]))
                                actual=region.extract_text() or ''
                                if actual.strip():rows[i][column]=actual.strip()
    return rows


if __name__ == '__main__':
    import pdfplumber
    import pypdfium2
    parser=argparse.ArgumentParser()
    parser.add_argument('--pdf',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    with pypdfium2.PdfDocument(args.pdf) as document:
        if len(document)!=180:raise ValueError('Wrong Yongin publication page scope')
        pages=[]
        for page in document:
            textpage=page.get_textpage()
            try:
                pages.append(textpage.get_text_range().replace('\r\n','\n').replace('\r','\n'))
            finally:
                textpage.close()
                page.close()
    if '2026학년도 2학기' not in '\n'.join(pages[:8]):
        raise ValueError('Wrong Yongin publication year/term')
    tables=[]
    with pdfplumber.open(args.pdf) as document:
        for number,page in enumerate(document.pages,1):
            if number in [86,90,91,94] or 98<=number<=178:
                for index,table in enumerate(page.find_tables()):
                    rows=extract_table_rows(page,table)
                    tables.append({'page':number,'table':index,'rows':rows})
    result=extract_records(tables,pages)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Yongin source records:',len(result['records']),len(result['remote']))
