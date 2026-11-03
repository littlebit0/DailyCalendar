"""Read the anonymous course screen's published department filters sequentially."""
import collections
import json
from pathlib import Path
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
PAGE = 'https://info.hansung.ac.kr/jsp_21/student/kyomu/siganpyo_aui.jsp?viewMode=oc'
ENDPOINT = urllib.parse.urljoin(PAGE, 'siganpyo_aui_data.jsp')
FIELDS = ('kwamokcode', 'kwamokname', 'isugubun', 'hakjum', 'juya', 'bunban',
          'haknean', 'haknean_limit', 'prof', 'classroom', 'plan', 'bigo',
          'kcomment', 'ekname', 'gwamokgun', 'kwamokgubun', 'cross_juya', 'excl_ext_stu')


def parse(raw):
    text = raw.decode('cp949')
    return ET.fromstring(text[text.index('<', text.index('?>') + 2):])


def request(params):
    req = urllib.request.Request(ENDPOINT, urllib.parse.urlencode(params).encode(),
                                 headers={'User-Agent': 'Mozilla/5.0', 'Referer': PAGE})
    with urllib.request.urlopen(req, timeout=35) as response:
        return response.read()


def main():
    departments = parse((ROOT / 'hansung-departments.xml').read_bytes())
    rows, scopes = [], []
    for item in departments.iter('item'):
        code, name = item.findtext('tcd'), item.findtext('tnm')
        raw = request({'gubun': 'history', 'syearhakgi': '20262', 'sjungong': code})
        (ROOT / f'hansung-{code}.xml').write_bytes(raw)
        records = parse(raw).findall('row')
        for record in records:
            rows.append({'departmentCode': code, 'departmentName': name,
                         **{key: record.findtext(key, '') for key in FIELDS}})
        scopes.append({'code': code, 'name': name, 'count': len(records)})
        if len(scopes) % 20 == 0:
            print(f'Completed {len(scopes)} scopes, {len(rows)} display rows', flush=True)
        time.sleep(.35)
    unique = {}
    conflicts = []
    for row in rows:
        key = (row['kwamokcode'], row['bunban'])
        value = {k: row[k] for k in FIELDS}
        if key in unique and unique[key] != value:
            conflicts.append({'key': key, 'fields': [k for k in FIELDS if unique[key][k] != value[k]]})
        unique.setdefault(key, value)
    core_fields = set(FIELDS) - {'isugubun', 'kwamokgubun', 'haknean'}
    core_conflicts = [entry for entry in conflicts if core_fields.intersection(entry['fields'])]
    for name, data in [('scopes', scopes), ('all-2026-2', rows),
                       ('unique-2026-2', list(unique.values())),
                       ('audit', {'scopes': len(scopes), 'displayRows': len(rows),
                                  'uniqueCourses': len(unique), 'conflicts': conflicts,
                                  'coreConflicts': core_conflicts,
                                  'metadataVariants': len(conflicts) - len(core_conflicts),
                                  'categories': dict(collections.Counter(r['isugubun'] for r in unique.values())),
                                  'emptySchedules': sum(not r['classroom'].strip() for r in unique.values()),
                                  'source': PAGE})]:
        (ROOT / f'hansung-{name}.json').write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(f'All {len(scopes)} public scopes complete: {len(unique)} unique courses, {len(conflicts)} conflicts', flush=True)


if __name__ == '__main__':
    main()
