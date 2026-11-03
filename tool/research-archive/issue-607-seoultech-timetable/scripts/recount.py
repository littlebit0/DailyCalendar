"""Recount Seoultech 2026-2 public GUEST timetable (no login). Output dir = argv[1]."""
import http.cookiejar, json, sys, time, urllib.request
from pathlib import Path
OUT = Path(sys.argv[1])
BASE = 'https://for-s.seoultech.ac.kr'
PAGE = BASE + '/html/pub/schedule.jsp'
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders = [('User-Agent', 'Mozilla/5.0 (compatible; DailyCalendar/1.0)'), ('Referer', PAGE)]
op.open(PAGE, timeout=30).read()
def q(data):
    time.sleep(0.6)
    r = urllib.request.Request(BASE + '/JSONMain', data=json.dumps(data).encode(), headers={'Content-Type': 'application/json; charset=utf-8'})
    return json.loads(op.open(r, timeout=40).read())
cmd = {k: '' for k in ['KEY_SQL_ID','KEY_INCREMENT','CALLBACK_SQL_ID','INSERT_SQL_ID','UPDATE_SQL_ID','DELETE_SQL_ID','EXEC','FAIL','FAIL_MSG','MSG']}
cmd.update(TYPE='N', SQL_ID='admin:LESS_SEARCH', SAVE_FLAG_COLUMN=None, KEY_ZERO_LEN=None, EXEC_TYPE='B', USE_INPUT='N', USE_ORDER='Y', EXEC_CNT=0)
depts = q({'SP_YMST': '20262', 'fsp_action': 'xDefaultAction', 'fsp_cmd': 'execute', 'fsp_ds_cmd': [cmd]})
(OUT / 'departments.json').write_text(json.dumps(depts, ensure_ascii=False, indent=1))
rows, scopes = [], []
for d in depts['ds_less']:
    for dn in ['00500001', '00500002']:
        p = {'fsp_action': 'GridAction', 'fsp_cmd': 'getScheduleGridData', 'SP_YMST': '20262', 'LESS_CD': d['ORGN_CD'], 'DN_DIV': dn, 'SUBJ_NM': '', 'LECT_DIV': '', 'DOTW_CD': ''}
        r = q(p)
        data = r.get('rows', [])
        if str(r.get('ErrorCode')) != '0' or int(r.get('records', -1)) != len(data):
            raise SystemExit(f'incomplete {d["ORGN_CD"]} {dn} {r.get("ErrorCode")} {r.get("records")} {len(data)}')
        scopes.append({'code': d['ORGN_CD'], 'name': d['ORGN_NM'], 'dn': dn, 'count': len(data)})
        rows += [{'queryDepartment': d['ORGN_CD'], 'dayNight': dn, 'row': x} for x in data]
(OUT / 'scopes.json').write_text(json.dumps(scopes, ensure_ascii=False, indent=1))
(OUT / 'rows.json').write_text(json.dumps(rows, ensure_ascii=False, indent=1))
print('depts', len(depts['ds_less']), 'queries', len(scopes), 'rows', len(rows), 'unique', len({(x['row']['SUBJ_CD'], x['row']['LECT_NUMB']) for x in rows}))
