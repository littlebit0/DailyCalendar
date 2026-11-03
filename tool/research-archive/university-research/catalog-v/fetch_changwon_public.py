"""Normal anonymous course-selector collection; educational whitelist only.

No login, credentials, enrollment counts, personal data, or queue bypass.
macOS curl is used because this school's TLS handshake rejects bundled Python.
"""
import hashlib
import json
import re
import subprocess
import time
import urllib.parse
from pathlib import Path

from lxml import html

ROOT = Path(__file__).resolve().parent
BASE = 'https://chains.changwon.ac.kr/cnu/haksa/open_subject/'


def fetch(page, parameters):
    response = subprocess.run(
        ['curl', '--fail', '--silent', '--show-error', '--max-time', '30',
         '--data', urllib.parse.urlencode(parameters), BASE + page],
        check=True, capture_output=True,
    )
    body = response.stdout
    document = html.fromstring(body.decode('utf-8'))
    text = document.text_content()
    if '로그인하세요' in text or '접근이 제한' in text:
        raise ValueError('Public collection stopped at access boundary')
    return body, document


def clean(cell):
    text = ' '.join(' '.join(cell.itertext()).split())
    text = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[연락처 생략]', text)
    return re.sub(r'\b0\d{1,2}[- ]\d{3,4}[- ]\d{4}\b', '[연락처 생략]', text)


def course_rows(document, query):
    results = []
    for row in document.xpath('//tr'):
        cells = row.xpath('./td')
        if not cells:
            continue
        identity = re.fullmatch(r'([A-Z]{3}\d{4})\((\d{2})\)', clean(cells[0]))
        if identity is None:
            continue
        if len(cells) != 30:
            raise ValueError(f'Unrecognized educational column count: {len(cells)}')
        fields = dict(zip(
            ['classification', 'title', 'credits', 'theoryPractice', 'professor',
             'schedule', 'eligibleYearDepartment', 'openingDepartment',
             'exchangePermission', 'competencies', 'lectureType', 'deliveryMode',
             'remoteSolution', 'examMode', 'examDateTime', 'examLocation', 'examNotes'],
            [clean(cells[i]) for i in [1, 2, 3, 4, 17, 18, 19, 20, 21, 22,
                                      23, 24, 25, 26, 27, 28, 29]],
        ))
        fields.update(code=identity[1], section=identity[2], query=query)
        results.append(fields)
    return results


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    parameters = {'year': '2026', 'term': '2', 'cyear': '2026'}
    body, top = fetch('open_top_manager.php', parameters)
    script = body.decode('utf-8')
    codes = dict(re.findall(r"dept00_code\[(\d+)\]='([^']+)';", script))
    names = dict(re.findall(r"dept00_name\[(\d+)\]='([^']+)';", script))
    assert len(codes) == len(names) and codes
    queries = [('0', '11', '학부교양전체'), ('2', '0', '학부교직'),
               ('9', '0', '학부원어강좌'), ('10', '0', '학부인터넷강좌'),
               ('11', '0', '학부자유선택')]
    queries += [('1', codes[k], names[k]) for k in codes]
    results, census = [], []
    for index, (big, detail, name) in enumerate(queries):
        p = dict(parameters, big=big, detail=detail, h_gubun=big,
                 h_grade=detail, keyword='')
        raw, document = fetch('open_down_manager.php', p)
        # Verify the actual selected semester, not an unrelated landing template.
        assert '2026 - 2 학기' in document.text_content()
        rows = course_rows(document, {'big': big, 'detail': detail, 'name': name})
        results.extend(rows)
        census.append({'query': rows[0]['query'] if rows else {'big': big, 'detail': detail, 'name': name},
                       'educationalRows': len(rows), 'bodySHA256': hashlib.sha256(raw).hexdigest()})
        if index % 10 == 0:
            print(f'Public selectors {index + 1}/{len(queries)}; educational rows {len(results)}', flush=True)
        time.sleep(0.6)
    closed_raw, closed = fetch('close_subjectlist.php', parameters)
    cancellations = []
    for row in closed.xpath('//tr'):
        cells = row.xpath('./td')
        if len(cells) == 9 and clean(cells[1]) == '학부':
            code, section = clean(cells[3]), clean(cells[4])
            assert re.fullmatch(r'[A-Z]{3}\d{4}', code) and re.fullmatch(r'\d{2}', section)
            cancellations.append({'code': code, 'section': section,
                                  'department': clean(cells[2]), 'title': clean(cells[5]),
                                  'professor': clean(cells[7]), 'closurePhase': clean(cells[8])})
    for name, value in [('changwon-current-educational-rows-20261008.json', results),
                        ('changwon-current-closures-20261008.json', cancellations),
                        ('changwon-normal-public-census-20261008.json', {
                            'sourceURL': BASE + 'open_index_manager.php',
                            'publicEntryURL': 'https://chains.changwon.ac.kr/nonstop/suup/sugang/hakbu/index.php',
                            'checkedAt': '2026-10-08', 'queries': census,
                            'selectorCount': len(queries), 'rows': len(results),
                            'closedBodySHA256': hashlib.sha256(closed_raw).hexdigest(),
                            'savedCountsOrCredentials': False, 'completionClaim': False})]:
        (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    print(f'Finished educational rows {len(results)}, UG closures {len(cancellations)}', flush=True)


if __name__ == '__main__':
    main()
