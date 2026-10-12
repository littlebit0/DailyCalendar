#!/usr/bin/env python3
"""Collect every public Gachon campus/category query without authentication.

The query and JSON envelope are published by ssu1000q.clx.js and Cleopatra's
JSONRequestBuilder. Retain only public course fields, never staff IDs or session
material. A dataset is complete only after all 12 scopes match rowCnt.
"""
import argparse
import json
from pathlib import Path
import time
import urllib.request

ENDPOINT = 'https://info.gachon.ac.kr/Ssu1000q/mainSearch.do'
PAGE = 'https://info.gachon.ac.kr/ssu/showTimetable.do'
CAMPUSES = ('20', '21')
CATEGORIES = ('001', '002', '003', '004', '005', '006')
PUBLIC_FIELDS = (
    'HAKSU_NO', 'SUBJECT_NM_KOR', 'ISU_NM', 'AREA_NM', 'SISU',
    'PRINT_DPT', 'PROFNM', 'TIME', 'LOC_NM', 'CYBER_YN',
)


def decode_response(data):
    if not isinstance(data, dict):
        raise ValueError('Invalid Gachon response')
    rows = data.get('MainData')
    count_record = data.get('dmRowCnt')
    if not isinstance(rows, list) or not isinstance(count_record, dict):
        raise ValueError('Missing Gachon published count')
    try:
        count = int(count_record['rowCnt'])
    except (KeyError, ValueError, TypeError):
        raise ValueError('Invalid Gachon published count') from None
    if count < 0 or count != len(rows):
        raise ValueError('Incomplete Gachon course response')
    ids = set()
    cleaned = []
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError('Invalid Gachon course record')
        code = row.get('HAKSU_NO')
        if not isinstance(code, str) or not code or code in ids:
            raise ValueError('Missing or repeated Gachon course identity')
        ids.add(code)
        cleaned.append({key: row.get(key) for key in PUBLIC_FIELDS})
    return cleaned


def write_json(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def collect(output, year, term):
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'year': year, 'term': term, 'complete': False, 'scopes': []}
    write_json(output / 'manifest.json', manifest)
    records = []
    for campus in CAMPUSES:
        for category in CATEGORIES:
            values = {
                'groupType': campus, 'searchYear': str(year), 'searchTerm': term,
                'searchUnivCD': '', 'searchDeptCD': '',
                'searchIsuCD': category, 'searchGrade': '',
                'searchSubjectNm': '',
            }
            request = urllib.request.Request(
                ENDPOINT,
                data=json.dumps({'data': {'SendData': values}}).encode(),
                headers={
                    'Content-Type': 'application/json;charset=UTF-8',
                    'User-Agent': 'Mozilla/5.0 (compatible; DailyCalendar/1.0)',
                    'Referer': PAGE,
                },
            )
            with urllib.request.urlopen(request, timeout=40) as response:
                rows = decode_response(json.loads(response.read()))
            write_json(output / f'{campus}-{category}.json', rows)
            records.extend(
                {'campus': campus, 'category': category, 'row': row}
                for row in rows
            )
            manifest['scopes'].append({
                'campus': campus, 'category': category, 'count': len(rows),
            })
            write_json(output / 'manifest.json', manifest)
            print(campus, category, len(rows), flush=True)
            time.sleep(.35)
    write_json(output / 'courses.json', records)
    manifest['complete'] = True
    write_json(output / 'manifest.json', manifest)
    print('Total public rows:', len(records), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--term', choices=('10', '11', '20', '21'), required=True)
    args = parser.parse_args()
    collect(args.output, args.year, args.term)


if __name__ == '__main__':
    main()
