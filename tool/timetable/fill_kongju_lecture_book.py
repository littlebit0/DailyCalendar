"""Fill Kongju 2026-2 course fields from the official lecture book (강의일람표).

Source: 2026학년도2학기 강의일람표 본책 (https://www.kongju.ac.kr/bbs/KNU/2128/655398/download.do),
kept as the frozen fixture
work/university-research/catalog-r/kongju/current-whole-lecture-list-followup-20261008/
current-whole-undergraduate-lecture-education.json.

Only fields the current datasets leave empty are filled, plus literal ditto
marks ("〃", "″") stored as a classification. Schedules, rooms, course codes
and names are never changed.

- 이수구분: the book prints "〃" for "same as the row above"; the earlier import
  kept the mark or an empty value. The value is carried down within one table.
- Contract-department rows (7-digit code + 2-digit section in the datasets)
  match the book's 9-digit 과목번호 exactly; their 이수구분, 교수 and 학점 are
  printed in the book but were missing.
- Major rows (이수구분 starting with 전) without a department get the book's
  department heading of their table, with its "(주)"/"(계약학과)" suffix removed.
  Each heading's college is the book section, checked against the official
  학부/대학원 page (https://www.kongju.ac.kr/KNU/16723/subview.do).

    python3 tool/timetable/fill_kongju_lecture_book.py <lecture-book.json>
"""
import collections
import json
import re
import sys
from pathlib import Path

DITTO = {'〃', '″'}
HEADING = re.compile(r'^\s*\d+(?:-\d+)?\.\s*(.+?)\s*\[[^\]]*\]\s*$')
BOOK_URL = 'https://www.kongju.ac.kr/bbs/KNU/2128/655398/download.do'
ORG_URL = 'https://www.kongju.ac.kr/KNU/16723/subview.do'
# Book sections (sourceTable ranges) and their college headings.
SECTIONS = [
    (239, 264, '사범대학'), (265, 280, '인문사회과학대학'),
    (281, 289, '자연과학대학'), (290, 331, '천안공과대학'),
    (332, 350, '산업과학대학'), (351, 356, '간호보건대학'),
    (357, 367, '예술대학'), (368, 371, None),
]
HQ_SECTION = (368, 371)  # 본부소속: no college, grouped under its faculty
DATASETS = sorted(Path('assets/timetable').glob('kongju-*-2026-2.json'))
ORG = Path('assets/timetable/organizations/kongju.json')


def label(heading):
    return re.sub(r'\((주|계약학과)\)\s*$', '', heading).strip()


def book_rows(path):
    book = json.loads(Path(path).read_text())
    rows, heading = {}, None
    for table in book['educationalTables']:
        for line in table['precedingEducationalContext']:
            m = HEADING.match(line)
            if m:
                heading = m.group(1)
        grid = collections.defaultdict(dict)
        for cell in table['cells']:
            for dr in range(cell.get('rowSpan', 1)):
                grid[cell['row'] + dr][cell['col']] = cell['text']
        cols = sorted(grid[0])
        names = [re.sub(r'\s', '', grid[0][c]) for c in cols]
        if '이수구분' not in names or '과목번호' not in names:
            continue
        last = None
        for r in sorted(grid)[1:]:
            rec = dict(zip(names, (grid[r].get(c, '') for c in cols)))
            value = rec['이수구분'].strip()
            if value in DITTO:
                value = last
            elif value:
                last = value
            code = rec['과목번호'].strip()
            if not re.fullmatch(r'\d{9}', code):
                continue
            entry = {
                'classification': (value or '').replace('\n', ''),
                'professor': rec.get('담당교수', '').strip(),
                'credits': rec.get('학점', '').strip(),
                'heading': heading,
                'table': table['sourceTable'],
            }
            # A course printed in several rows (team teaching, shared tables)
            # keeps a field only when every copy prints the same value.
            if code in rows:
                prev = rows[code]
                for k in ('classification', 'professor', 'credits', 'heading'):
                    if prev[k] != entry[k]:
                        prev[k] = '' if k != 'heading' else None
                continue
            rows[code] = entry
    return rows


def college_for(table):
    for start, end, college in SECTIONS:
        if start <= table <= end:
            return college
    return None


def main(book_path, datasets=DATASETS, org_path=ORG):
    rows = book_rows(book_path)
    org = json.loads(Path(org_path).read_text())
    known = {(m['sourceLabel'], m.get('campus')) for m in org['mappings']}
    counts = collections.Counter()
    new_labels = {}
    for path in map(Path, datasets):
        data = json.loads(path.read_text())
        for c in data['courses']:
            code = c['courseCode'] if len(c['courseCode']) == 9 else c['courseCode'] + c['section']
            row = rows.get(code)
            if row is None:
                continue
            note = []
            have = c.get('classification') or ''
            if (not have or have in DITTO) and row['classification']:
                c['classification'] = row['classification']
                counts['classification'] += 1
                note.append('이수구분')
            if not c.get('professor') and row['professor']:
                c['professor'] = row['professor']
                counts['professor'] += 1
                note.append('담당교수')
            if c.get('credits') is None and re.fullmatch(r'\d+(\.\d+)?', row['credits']):
                c['credits'] = float(row['credits'])
                counts['credits'] += 1
                note.append('학점')
            cls = c.get('classification') or ''
            if not c.get('departments') and cls.startswith('전') and row['heading']:
                college = college_for(row['table'])
                if college is None and not HQ_SECTION[0] <= row['table'] <= HQ_SECTION[1]:
                    raise ValueError(f'no college section for table {row["table"]}')
                dept = label(row['heading'])
                c['departments'] = [dept]
                new_labels.setdefault((dept, data['campus']), (college, row['table']))
                counts['departments'] += 1
                note.append('개설 학과')
            for dept in c.get('departments') or []:
                # A department value that is itself a ditto mark is unresolved too.
                if cls and (c.get('departmentClassifications') or {}).get(dept, '') in ('', *DITTO):
                    c.setdefault('departmentClassifications', {})[dept] = cls
                if c.get('credits') is not None and dept not in (c.get('departmentCredits') or {}):
                    c.setdefault('departmentCredits', {})[dept] = c['credits']
            if note:
                c['remarks'] = ((c.get('remarks') or '') + (
                    f' {"·".join(note)}: 2026-2 강의일람표 본책 과목번호 {code} 행 원문.')).strip()
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    for (dept, campus), (college, table) in sorted(new_labels.items()):
        if (dept, campus) in known:
            continue
        group = None if college else re.sub(r'\(.*$', '', dept)
        org['mappings'].append({
            'college': college, 'group': group,
            **({'officialGroups': [group]} if group else {}),
            'department': dept, 'sourceLabel': dept,
            'sourceUrl': BOOK_URL,
            'evidence': f'2026-2 강의일람표 본책 {college or "본부소속"} 단원 표 {table}의 학과 제목 "{dept}" 직접기록',
            'sourceFile': 'work/university-research/catalog-r/kongju/current-whole-lecture-list-followup-20261008/current-whole-undergraduate-lecture-education.json',
            'isOfferingUnit': False, 'campus': campus, 'collegeKnown': college is not None,
            'affiliationStatus': 'verified', 'affiliationSourceUrl': ORG_URL,
            'affiliationEvidence': f'공식 홈페이지 학부/대학원 안내의 {college or "본부소속 " + group} 목록과 강의일람표 단원 일치',
        })
        counts['mappings'] += 1
    Path(org_path).write_text(json.dumps(org, ensure_ascii=False, separators=(',', ':')))
    return counts
    print(dict(counts))


if __name__ == '__main__':
    main(sys.argv[1])
