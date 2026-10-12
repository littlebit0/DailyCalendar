#!/usr/bin/env python3
"""Collect all official public HUFS undergraduate query scopes sequentially.

This is a catalog collector, not an authentication or LMS tool. No credentials
are needed. Only public course fields are retained; employee IDs and failed raw
responses are not stored. A manifest is complete only after all scopes succeed.
"""
import argparse
import json
from pathlib import Path
import time
import urllib.parse
import urllib.request

BASE = 'https://wis.hufs.ac.kr'
SOURCE = BASE + '/src08/jsp/lecture/LECTURE2020L.jsp'
SCOPES = [
    ('1', 'process3_1a', 'hakkwaCode1', 'hakkwaName1'),
    ('2', 'process4_1a', 'fieldCode2', 'fieldName2'),
    ('3', 'process4_1b', 'fieldCode2', 'fieldName2'),
    ('4', 'process4_1c', 'hakkwaCode1', 'hakkwaName1'),
]
PUBLIC_FIELDS = [
    'lssnCd', 'subjtNaKr', 'empNm', 'unitNum', 'dayTimeDisplay', 'dayTime',
    'dayTimeTemp', 'etc', 'etc2', 'etc3', 'etc4', 'comptFldNm', 'comptFldCd',
    'crsNm', 'crsStrctCd', 'dstGrad', 'gubun', 'campus', 'ledgYear',
    'ledgSessn', 'orgSect', 'realLssnNum', 'cyberFlag', 'wongangFlag',
    'moocFlag', 'focusLect', 'lang', 'encessFlag', 'ttFlag',
]


def decode_response(body):
    response = json.loads(urllib.parse.unquote(body))
    if not isinstance(response, dict) or response.get('rtnCode') != '1':
        raise ValueError('Unsuccessful HUFS public response')
    count = int(response.get('dataCount', -1))
    rows = response.get('data')
    if count == 0 and rows is None:
        return []
    if count == 1 and isinstance(rows, dict):
        return [rows]
    if not isinstance(rows, list) or len(rows) != count:
        raise ValueError('Incomplete HUFS public response')
    return rows


def query(parameters):
    time.sleep(.35)
    request = urllib.request.Request(
        BASE + '/hufs', data=urllib.parse.urlencode(parameters).encode(),
        headers={'Referer': SOURCE},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read(8_000_001)
    if len(body) > 8_000_000:
        raise ValueError('Oversized HUFS public response')
    return decode_response(body.decode())


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def collect(output, year, resume=False):
    output.mkdir(parents=True, exist_ok=True)
    # Invalidate any previous complete result before a new collection starts.
    manifest_path = output / 'manifest.json'
    write_json(manifest_path, {'complete': False, 'year': year, 'semester': '2'})
    partial_path = output / 'courses.partial.json'
    previous = json.loads(partial_path.read_text()) if resume and partial_path.exists() else []
    cached = {}
    for record in previous:
        row = record['row']
        if str(row.get('ledgYear')) == str(year) and row.get('ledgSessn') == '3':
            key = (record['queryCampus'], record['queryCategory'], record['queryDepartment'])
            cached.setdefault(key, []).append(row)
    results = []
    counts = {}
    for campus in ['H1', 'H2']:
        for category, method, code_key, name_key in SCOPES:
            common = {'org_sect': 'A', 'ledg_year': str(year),
                      'ledg_sessn': '3', 'campus': campus}
            groups = query(dict(common, mName=method, cName='hufs.stu1.STU1_C008'))
            if not groups:
                raise ValueError('Missing HUFS public category groups')
            names = [group[name_key] for group in groups]
            if len(set(names)) != len(names):
                raise ValueError('Conflicting HUFS public group names')
            count = {'groups': len(groups), 'courses': 0}
            for group in groups:
                key = (campus, category, group[name_key])
                parameters = dict(common, mName='getDataLssnLista',
                    cName='hufs.stu1.STU1_C009', crs_strct_cd=group[code_key],
                    gubun=category, subjt_nm='', won='', cyber='', emp_nm='', pf='%')
                parameters.update({f'd{i}': 'N' for i in range(1, 7)})
                parameters.update({f't{i}': 'N' for i in range(1, 13)})
                rows = cached[key] if key in cached else query(parameters)
                for row in rows:
                    if (row.get('ledgYear') != str(year) or row.get('ledgSessn') != '3'
                            or row.get('orgSect') != 'A' or row.get('campus') != campus):
                        raise ValueError('Wrong HUFS public course term or campus')
                    results.append({'queryCampus': campus, 'queryCategory': category,
                        'queryDepartment': group[name_key],
                        'row': {field: row.get(field) for field in PUBLIC_FIELDS}})
                count['courses'] += len(rows)
                write_json(partial_path, results)
            counts[campus + '/' + category] = count
            print(campus, category, count, flush=True)
    write_json(output / 'courses.json', results)
    write_json(manifest_path, {'complete': True, 'year': year, 'semester': '2',
        'sourceTerm': '3', 'counts': counts, 'sourceUrl': SOURCE})
    print('Complete', len(results), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--resume', action='store_true',
        help='Resume an interrupted collection of the same term; omit to refresh all courses.')
    args = parser.parse_args()
    collect(args.output, args.year, args.resume)
