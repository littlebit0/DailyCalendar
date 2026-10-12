#!/usr/bin/env python3
"""Collect official anonymous INHA course menu filters sequentially. No login."""
from urllib.request import Request, build_opener, HTTPCookieProcessor
from urllib.parse import urlencode
from http.cookiejar import CookieJar
from html.parser import HTMLParser
from pathlib import Path
import time, re, json
URL = 'https://sugang.inha.ac.kr/sugang/SU_51001/Lec_Time_Search.aspx'

class Page(HTMLParser):

    def __init__(self):
        super().__init__()
        self.fields = {}
        self.options = {}
        self.select = None
        self.option = None
        self.in_grid = False
        self.row = None
        self.cell = None
        self.rows = []
        self.term = None
        self.text = None

    def handle_starttag(self, t, a):
        a = dict(a)
        if t == 'input' and a.get('name'):
            if a.get('type') in ['hidden', 'text'] or (a.get('type') == 'radio' and 'checked' in a):
                self.fields[a['name']] = a.get('value', '')
        if t == 'select':
            self.select = a.get('name')
            self.options[self.select] = []
        if t == 'option' and self.select:
            self.option = [a.get('value', ''), '', 'selected' in a]
        if t == 'table' and a.get('id') == 'dgList':
            self.in_grid = True
        if t == 'tr' and self.in_grid:
            self.row = []
        if t == 'td' and self.row is not None:
            self.cell = []
        if t == 'br' and self.cell is not None:
            self.cell.append('\n')
        if a.get('id') == 'lblYearTerm':
            self.text = []

    def handle_data(self, s):
        if self.option:
            self.option[1] += s
        if self.cell is not None:
            self.cell.append(s)
        if self.text is not None:
            self.text.append(s)

    def handle_endtag(self, t):
        if t == 'option' and self.option:
            self.options[self.select].append(self.option[:2])
            if self.option[2] or self.select not in self.fields:
                self.fields[self.select] = self.option[0]
            self.option = None
        if t == 'select':
            self.select = None
        if t == 'td' and self.cell is not None:
            self.row.append(''.join(self.cell).strip())
            self.cell = None
        if t == 'tr' and self.row is not None:
            if self.row and self.row != ['해당자료가 없습니다.']:
                self.rows.append(self.row)
            self.row = None
        if t == 'table' and self.in_grid:
            self.in_grid = False
        if t == 'span' and self.text is not None:
            self.term = ''.join(self.text).strip()
            self.text = None

def fetch(directory, year, semester):
    """Write only public rows, and mark complete after every published filter.

 Anonymous POST state stays in memory. Do not invoke employee lookup or save
 cookies, hidden ASP.NET state or report URL parameters in collected files.
 """
    directory.mkdir(parents=True, exist_ok=True)
    op = build_opener(HTTPCookieProcessor(CookieJar()))
    headers = {'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)', 'Referer': URL}

    def read(fields=None):
        request = Request(URL, None if fields is None else urlencode(fields).encode(), headers=headers)
        with op.open(request, timeout=30) as response:
            if response.status != 200:
                raise ValueError('INHA course menu unavailable')
            body = response.read(8000001)
            if len(body) > 8000000:
                raise ValueError('INHA course response too large')
        page = Page()
        page.feed(body.decode('utf-8'))
        if page.term != f'{year} 학년도 {semester}학기':
            raise ValueError('Unexpected INHA published term')
        if any((len(row) != 14 for row in page.rows)):
            raise ValueError('Unexpected INHA row shape')
        return page
    page = read()
    queries = [('department', code, label, 'ibtnSearch1', 'ddlDept') for (code, label) in page.options['ddlDept']] + [('other', code, label, 'ibtnSearch2', 'ddlKita') for (code, label) in page.options['ddlKita']]
    if not queries or len({(kind, code) for (kind, code, *_) in queries}) != len(queries):
        raise ValueError('Invalid INHA published filters')
    manifest = {'year': year, 'semester': semester, 'sourceUrl': URL, 'queries': [{'kind': kind, 'code': code, 'label': label} for (kind, code, *_) in queries]}
    (directory / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    for (kind, code, label, button, field) in queries:
        if not re.fullmatch('[0-9]+', code):
            raise ValueError('Invalid public filter code')
        time.sleep(0.5)
        fields = dict(page.fields)
        fields.update({button: '조회', field: code, '__EVENTTARGET': '', '__EVENTARGUMENT': '', 'mb_search': ''})
        page = read(fields)
        out = {'term': page.term, 'kind': kind, 'code': code, 'label': label, 'rows': page.rows, 'timeOptions': page.options['ddlTime1']}
        (directory / (kind + '-' + code + '.json')).write_text(json.dumps(out, ensure_ascii=False) + '\n')
        print(kind, code, len(page.rows), flush=True)
    manifest['complete'] = True
    (directory / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--semester', choices=['1', '2'], required=True)
    args = parser.parse_args()
    fetch(args.output, args.year, args.semester)
