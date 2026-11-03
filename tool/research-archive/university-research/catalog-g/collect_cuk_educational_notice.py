"""Bounded public educational notice extraction; no full profiles/contact fields."""
import hashlib
import html
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parent


def clean(value):
    return re.sub(r'\s+', ' ', html.unescape(re.sub('<[^>]+>', ' ', value))).strip()


def collect(url, filename, keywords):
    response = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30)
    if response.status != 200:
        raise RuntimeError('Non-success response; no fallback')
    raw = response.read()
    source = raw.decode('utf-8')
    start = re.search(r'<div[^>]+class="b-content-box"[^>]*>', source)
    if start is None:
        raise RuntimeError('Published content missing; stop')
    depth = 1
    end = None
    for match in re.finditer(r'<div\b[^>]*>|</div>', source[start.end():]):
        depth += -1 if match.group().startswith('</') else 1
        if depth == 0:
            end = start.end() + match.start()
            break
    if end is None:
        raise RuntimeError('Content boundary missing; stop')
    content = source[start.end():end]
    tables = [[[clean(cell) for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', row, re.S)]
               for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', table, re.S)]
              for table in re.findall(r'<table\b[^>]*>(.*?)</table>', content, re.S)]
    # Tables here must be educational operating/course tables, never rosters.
    if any('학번' in ' '.join(row) and '성명' in ' '.join(row) for table in tables for row in table):
        raise RuntimeError('Unexpected roster; no persistence')
    paragraphs = [clean(part) for part in re.split(r'</p>|<br[^>]*>', content)]
    excerpts = [part for part in paragraphs if len(part) < 2000 and '@' not in part
                and not re.search(r'\d{2,3}-\d{3,4}-\d{4}', part)
                and any(word in part for word in keywords)]
    result = {'sourceUrl': url, 'sourceSha256': hashlib.sha256(raw).hexdigest(),
              'educationTables': tables, 'educationExcerpts': excerpts,
              'policy': 'Public course operating evidence only; no raw HTML, account, profile or contact persistence.'}
    (ROOT / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    return result


if __name__ == '__main__':
    result = collect('https://www.cuk.ac.kr/ko/campuslife/notice.do?mode=view&articleNo=274075',
                     'cuk-current-volunteer-operation-20261008.json',
                     ['교과목 구성', '기초소양', '분반', '봉사활동', '2026', '출석', '수업'])
    print(json.dumps({'tables': len(result['educationTables']), 'excerpts': len(result['educationExcerpts'])}))
