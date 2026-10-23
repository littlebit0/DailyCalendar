#!/usr/bin/env python3
"""Collect Konkuk's public 2026-2 undergraduate timetables without login.

Seoul: the 종합강의시간표 조회 page linked from
https://www.konkuk.ac.kr/konkuk/2367/subview.do posts the same form fields to
/sugang/search?attribute=lectListOuter for every 이수구분 × 대학 × 학과 choice the
page offers. GLOCAL: the 강의시간표 조회 page linked from the GLOCAL 학사공지
(BBS_SEQ=120132) reads /wsugang/core?attribute=timeList per menu and opening
unit. Only public course fields are kept; any duplicate offering number whose
fields disagree aborts the collection.
"""
import argparse
import json
from pathlib import Path
import time
import urllib.parse
import urllib.request

UA = 'Mozilla/5.0 (compatible; DailyCalendar/1.0)'
SEOUL = 'https://sugang.konkuk.ac.kr/sugang'
SEOUL_PAGE = SEOUL + '/jsp/search/searchMainOuter.jsp'
GLOCAL = 'http://kupis.kku.ac.kr/wsugang'
GLOCAL_PAGE = GLOCAL + '/core?attribute=timeMain'
# The page's own select options. 일선·교직·기교·심교 force 전체대학/전체 (fnPobtChg).
SEOUL_WHOLE = ('B04046', 'B04047', 'B0404P', 'B04054')
SEOUL_UNIT = ('B04045', 'B04044', 'B0404O', 'B04043', 'B04061',
              'B04065', 'B04071', 'B04072')
SEOUL_FIELDS = (
    'haksu_id', 'pobt_div', 'pobt_div_nm', 'sbjt_id', 'clss_no', 'typl_nm',
    'pnt', 'tm', 'lt_knd', 'lt_knd_nm', 'lang_type_nm', 'remk',
    'cult_cors_fld', 'old_cult_cors_fld', 'open_shyr', 'open_sust_nm',
    'kor_nm', 'room_nm', 'open_yy',
)
GLOCAL_FIELDS = (
    'shyr', 'isu_nm', 'lec_no', 'lec_nm', 'sugang_remk', 'pnt', 'tm',
    'lec_tm', 'prof', 'remk', 'haksu_id', 'open_sust', 'clss_no', 'pobt_div',
    'lt_knd', 'clse_fg', 'sust_list', 'lt_type_nm', 'intensive_nm',
)
SLEEP = .6


def request(url, data=None, referer=None, opener=None):
    body = None if data is None else urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        'User-Agent': UA, 'X-Requested-With': 'XMLHttpRequest',
        **({'Referer': referer} if referer else {}),
    })
    for attempt in range(3):
        try:
            with opener.open(req, timeout=90) as response:
                raw = response.read()
            break
        except OSError:
            if attempt == 2:
                raise
            time.sleep(5)
    time.sleep(SLEEP)
    for encoding in ('utf-8', 'cp949'):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise ValueError('Undecodable response: ' + url)
    rows = json.loads(text.strip())['rows']
    if not isinstance(rows, list):
        raise ValueError('Invalid rows: ' + url)
    return rows


def merge(store, key, row, scope):
    previous = store.get(key)
    if previous is None:
        store[key] = {'row': row, 'scopes': [scope]}
        return
    if previous['row'] != row:
        raise ValueError(f'Conflicting duplicate offering {key}')
    if scope not in previous['scopes']:
        previous['scopes'].append(scope)


def write_json(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    temporary.replace(path)


def seoul(output, year, term):
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor())
    opener.open(urllib.request.Request(SEOUL_PAGE, headers={'User-Agent': UA}),
                timeout=60).read()
    base = {'pYear': str(year), 'pTerm': term, 'lang': 'ko'}
    combo = SEOUL + '/search?attribute=cbxList&gbn='
    colleges = request(combo + 'U', {**base, 'pUniv': '', 'pSustMjCd': ''},
                       SEOUL_PAGE, opener)
    units = {}
    for college in colleges:
        code = college['code']
        units[(code, code)] = college['name'].strip()
        for unit in request(combo + 'M', {**base, 'pUniv': code, 'pSustMjCd': ''},
                            SEOUL_PAGE, opener):
            path = [p for p in unit['ord'].split(',') if p]
            units[(code, unit['code'])] = unit['name'].strip()
            # Intermediate schools in the tree (ord) are opening units too.
            for parent in path[1:-1]:
                units.setdefault((code, parent), '')
    store = {}
    scopes = []
    plan = [(p, '006751', '006751') for p in SEOUL_WHOLE + ('B04065',)]
    plan += [(p, college, unit) for p in SEOUL_UNIT
             for (college, unit) in sorted(units) if college != '006751']
    for index, (pobt, college, unit) in enumerate(plan):
        rows = request(SEOUL + '/search?attribute=lectListOuter', {
            **base, 'pPobt': pobt, 'pSearchGb': '1', 'pUniv': college,
            'pSustMjCd': unit, 'pLang': '', 'pKind': '', 'pSearchKind': '1',
            'pSearchNm': '', '_search': 'false', 'rows': '10000', 'page': '1',
        }, SEOUL_PAGE, opener)
        if any(r.get('code') in ('999', '500') for r in rows):
            raise ValueError('Seoul query refused')
        scope = {'pobt': pobt, 'college': college, 'unit': unit,
                 'unitName': units.get((college, unit), ''), 'count': len(rows)}
        scopes.append(scope)
        for row in rows:
            if row.get('open_yy') is None or not row.get('sbjt_id'):
                raise ValueError('Missing Seoul offering number')
            kept = {k: row.get(k) for k in SEOUL_FIELDS}
            merge(store, row['sbjt_id'], kept, [pobt, college, unit])
        if index % 50 == 0:
            print('seoul', index, len(plan), len(store), flush=True)
    write_json(output / 'seoul.json', {
        'year': year, 'term': term, 'sourceUrl': SEOUL_PAGE,
        'colleges': colleges, 'units': [
            {'college': c, 'unit': u, 'name': n} for (c, u), n in sorted(units.items())],
        'scopes': scopes, 'offerings': store, 'complete': True,
    })
    print('seoul total', len(store), flush=True)


def glocal(output, year, term, seed_units):
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor())
    opener.open(urllib.request.Request(GLOCAL_PAGE, headers={'User-Agent': UA}),
                timeout=60).read()
    seeds = json.loads(seed_units.read_text())
    store = {}
    scopes = []

    def query(menu, code=None, name=''):
        url = (f'{GLOCAL}/core?attribute=timeList&year={year}&hakgi={term}'
               f'&menu={menu}' + (f'&lectCd={code}' if code else '')
               + '&_search=false&rows=2000&page=1')
        rows = request(url, None, GLOCAL_PAGE, opener)
        scopes.append({'menu': menu, 'lectCd': code, 'name': name,
                       'count': len(rows)})
        for row in rows:
            if not row.get('lec_no'):
                raise ValueError('Missing GLOCAL offering number')
            kept = {k: row.get(k) for k in GLOCAL_FIELDS}
            merge(store, row['lec_no'], kept, [menu, code or '', name])
        return rows

    for menu in ('5', '10', '9'):
        query(menu)
    for area in seeds['cultArea']:
        menu = {'B04056': '4', 'B04060': '11', 'B04058': '12',
                'B04059': '13'}[area['temp_cd']]
        query(menu, area['lec_cd'], area['lec_nm'])
    names = {u['lec_cd']: u['lec_nm'] for u in seeds['hakgwa']}
    done = set()
    # Opening units seen in any result are queried too, until none is new.
    while True:
        pending = (set(names) | {e['row']['open_sust'] for e in store.values()}) - done
        if not pending:
            break
        for code in sorted(pending):
            query('1', code, names.get(code, ''))
            done.add(code)
    write_json(output / 'glocal.json', {
        'year': year, 'term': term, 'sourceUrl': GLOCAL_PAGE,
        'seedSource': seeds['source'], 'unitNames': names,
        'scopes': scopes, 'offerings': store, 'complete': True,
    })
    print('glocal total', len(store), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--campus', choices=('seoul', 'glocal'), required=True)
    parser.add_argument('--glocal-seed', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.campus == 'seoul':
        seoul(args.output, 2026, 'B01012')
    else:
        glocal(args.output, 2026, 'B01012', args.glocal_seed)


if __name__ == '__main__':
    main()
