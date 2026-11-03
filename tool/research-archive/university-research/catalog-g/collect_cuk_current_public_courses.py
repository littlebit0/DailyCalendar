"""Follow the school's actual anonymous current-course next links once."""
import collections
import hashlib
import html
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FIRST = 'https://www.catholic.ac.kr/ko/support/subject.do?mode=list&sust=ALL&pobtFg=&year=2026&openShtm=20&srSearchVal=&isEngCourses=N&alignKey='


def text(value):
    return re.sub(r'\s+', ' ', html.unescape(re.sub('<[^>]+>', ' ', value))).strip()


def parse_courses(source):
    match = re.search(r'<table class="b-courses-offered-table">(.*?)</table>', source, re.S)
    if not match:
        raise ValueError('Published course table missing; no fallback')
    courses = []
    for row in re.findall(r'<tr>(.*?)</tr>', match.group(1), re.S):
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.S)
        if len(cells) != 5:
            continue
        code, title, category, section = map(text, cells[:4])
        details = {text(k).rstrip(':'): text(v) for k, v in re.findall(r'<p>([^<>]*)</p><span>(.*?)</span>', cells[4], re.S)}
        if not re.fullmatch(r'\d{5}', code) or not section:
            raise ValueError('Missing real published code/section')
        if details.get('과목번호') != code or details.get('분반') != section or details.get('교과목명') != title:
            raise ValueError('Outer/detail identity mismatch')
        courses.append({'code': code, 'section': section, 'title': title, 'classification': category,
                        'department': details['개설학과'], 'professor': details['담당교수'],
                        'rawTimeAndRoom': details['시간표'], 'remarks': details['비고'],
                        'credits': None, 'campus': None})
    return courses


def next_url(source, current):
    offset = int(urllib.parse.parse_qs(urllib.parse.urlsplit(current).query).get('article.offset', ['0'])[0])
    links = []
    for raw in re.findall(r'<a[^>]*href="([^"]*article\.offset=[^"]*)"', source):
        actual = urllib.parse.urljoin(current, html.unescape(raw))
        parsed = urllib.parse.urlsplit(actual)
        if parsed.netloc != 'www.catholic.ac.kr' or parsed.path != '/ko/support/subject.do':
            continue
        query = urllib.parse.parse_qs(parsed.query)
        if query.get('year') != ['2026'] or query.get('openShtm') != ['20'] or query.get('sust') != ['ALL']:
            continue
        n = int(query['article.offset'][0])
        if n > offset:
            links.append((n, actual))
    return min(links)[1] if links else None


def collect():
    url = FIRST
    courses = []
    pages = []
    seen = set()
    while url:
        if url in seen or len(pages) >= 40:
            raise ValueError('Pagination did not terminate normally')
        seen.add(url)
        if not pages:
            source_bytes = Path('/private/tmp/cuk-current2026-2-whole.html').read_bytes()
            status = 200
        else:
            request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Accept-Language': 'ko-KR,ko;q=0.9', 'Referer': FIRST})
            response = urllib.request.urlopen(request, timeout=40)
            status = response.status
            source_bytes = response.read()
        if status != 200:
            raise ValueError('Non-success or protection response; stop')
        source = source_bytes.decode('utf-8')
        if not re.search(r'<option value="2026" selected>', source) or not re.search(r'<option value="20" selected>', source):
            raise ValueError('Year/semester source changed')
        part = parse_courses(source)
        if not part:
            raise ValueError('Unexpected empty current table; stop')
        page = {'url': url, 'status': status, 'bytes': len(source_bytes), 'sha256': hashlib.sha256(source_bytes).hexdigest(), 'educationRows': len(part)}
        following = next_url(source, url)
        checkpoint = {'sourcePage': page, 'nextPublishedUrl': following, 'courses': part}
        (ROOT / ('cuk-current-education-page-' + str(len(pages) + 1).zfill(2) + '-20261008.json')).write_text(json.dumps(checkpoint, ensure_ascii=False, indent=2) + '\n')
        pages.append(page)
        courses.extend(part)
        url = following
        print('page', len(pages), 'educationRows', len(courses), flush=True)
        if url:
            time.sleep(1)
    keys = [(c['code'], c['section']) for c in courses]
    duplicates = collections.defaultdict(list)
    for course in courses:
        duplicates[course['code'] + '-' + course['section']].append(course)
    duplicate_groups = {key: rows for key, rows in duplicates.items() if len(rows) > 1}
    result = {'school': '가톨릭대학교', 'sourceScope': 'Official main campuslife current course menu; campus remains null until actual scope corroborated', 'sourceYear': 2026, 'sourceSemester': '20', 'observedDate': '2026-10-08', 'productionReady': False, 'sourcePages': pages, 'courses': courses}
    path = ROOT / 'cuk-current-whole-education-20261008.json'
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    audit = {'wholeEducationRows': len(courses), 'uniqueCodeSection': len(set(keys)), 'duplicateCodeSectionGroups': duplicate_groups, 'identityPolicy': 'All published rows preserved; duplicate code/section never silently collapsed.', 'actualPublishedPages': len(pages), 'creditsSourceMissing': len(courses), 'scheduled': 0, 'classificationCounts': dict(collections.Counter(c['classification'] for c in courses)), 'departmentCounts': dict(collections.Counter(c['department'] for c in courses)), 'sourceSha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'productionReady': False, 'remaining': ['Actual current credit/hours code joins', 'General and special current clock', 'Operating dates/holiday/makeup exceptions', 'Closure/current published membership semantics', 'Source campus scope']}
    (ROOT / 'cuk-current-whole-education-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(audit, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    collect()
