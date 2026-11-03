"""Actual Dart-extracted monthly/holiday scope audit, research only."""
import datetime as dt
import json
import re
from pathlib import Path
ROOT = Path(__file__).parent
DATE_PREFIX = re.compile(r'^(\d{1,2}(?:[/.]\s*\d{1,2})?\([월화수목금토일]\)(?:\s*,\s*\d{1,2}\([월화수목금토일]\))?(?:\s*~\s*(?:\d{1,2}[/.]\s*)?\d{1,2}\.?\([월화수목금토일]\))?)\s+(.+)$')


def numeric(raw, year, month):
    clean = re.sub(r'\([월화수목금토일]\)', '', raw).replace(' ', '').replace('/', '.')
    out = []
    for part in clean.split(','):
        edges = part.split('~')
        def date(s, context):
            bits = s.strip('.').split('.')
            return dt.date(year, context if len(bits)==1 else int(bits[0]), int(bits[-1]))
        start = date(edges[0], month)
        end = date(edges[-1], start.month)
        if end < start:
            end = dt.date(year+1, end.month, end.day)
        out.append((start.isoformat(), end.isoformat()))
    return out


def audit(text):
    month = None; year = 2026; in_months = False; rows = []; scopes = []; footnotes = []
    for page_index, page in enumerate(text.split('PAGE_BOUNDARY')):
        for line_number, raw in enumerate(page.splitlines(), 1):
            line = raw.strip()
            if not line: continue
            if line == '월 일 정 학 사 일 정':
                in_months = True
                continue
            if line.startswith('§'):
                in_months = False
            if not in_months:
                for m in re.finditer(r'([가-힣0-9\s]+?)\s+(2026\.\d{2}\.\d{2}\.\([월화수목금토일]\)(?:\s*~\s*\d{2}\.\d{2}\.\([월화수목금토일]\))?)', line):
                    title = m[1].strip(); dates = m[2]
                    footnotes.append({'title': title, 'sourceDate': dates, 'page': page_index+1, 'line': line_number})
                continue
            if re.fullmatch(r'\d{4}\.\s*\d{1,2}', line):
                year, month = map(int, line.replace('.', ' ').split()); scopes.append((year, month)); continue
            if re.fullmatch(r'\d{1,2}', line):
                month = int(line);scopes.append((year,month));continue
            inline = re.match(r'^(\d{1,2})\s+(\d{1,2}\([월화수목금토일]\).*)$', line)
            if inline:
                month = int(inline[1]);scopes.append((year,month));line=inline[2]
            match = DATE_PREFIX.match(line)
            if match and month:
                for start,end in numeric(match[1],year,month):
                    rows.append({'title':match[2], 'startDate':start,'endDateInclusive':end,'sourcePage':page_index+1,'sourceLine':line_number})
            elif re.fullmatch(r'\d{1,2}\([월화수목금토일]\)', line) and month:
                # Actual March2027 date/title is broken onto separate lines.
                start,end = numeric(line,year,month)[0]
                rows.append({'title':'', 'startDate':start,'endDateInclusive':end,'sourcePage':page_index+1,'sourceLine':line_number})
            elif rows and rows[-1]['title']=='':
                rows[-1]['title']=line
    expected=[(2026,m) for m in range(1,13)]+[(2027,m) for m in range(1,4)]
    if scopes != expected:raise ValueError(f'Unexpected actual month scope {scopes}')
    if any(not r['title'] for r in rows):raise ValueError('Unrecognized wrapped title')
    return {'source':'hoseo-current-revised-pdf1-dart-extractor.txt','monthScope':scopes,'rows':rows,'normalEventCount':len(rows),'normal2026EventCount':sum(r['startDate'].startswith('2026') for r in rows),'holidayFootnotes':footnotes,'holidayCount':len(footnotes),'productionEdited':False}

if __name__=='__main__':
    result=audit((ROOT/'hoseo-current-revised-pdf1-dart-extractor.txt').read_text())
    (ROOT/'hoseo-revised-dart-text-scope-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(result['normalEventCount'], result['normal2026EventCount'], result['holidayCount'])
