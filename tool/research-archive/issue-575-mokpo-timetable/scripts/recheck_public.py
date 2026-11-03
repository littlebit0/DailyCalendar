"""2026-2 공개 학부 시간표(UNCO04) 전체 재조회 후 이전 수집본과 대조. 로그인 없음, 익명 세션만 메모리에 둔다."""
import sys, json, time, xml.etree.ElementTree as ET
sys.path.insert(0, '/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-m')
import mokpo_public_protocol as p
import urllib.request
p.urllib.request.Request.__init__.__defaults__  # noqa
UA = 'Mozilla/5.0 (compatible; DailyCalendar/1.0)'
_orig = urllib.request.Request.__init__
def _init(self, url, data=None, headers={}, *a, **k):
    headers = dict(headers); headers['User-Agent'] = UA
    _orig(self, url, data, headers, *a, **k)
urllib.request.Request.__init__ = _init
o = p.bootstrap(); time.sleep(0.6)
yb = p.query(o, 'sy/sycm/sycm90:YEAR_HAKGI_S03', {'MENU_CD': 'UNCO'}); time.sleep(0.6)
yr = [(e.attrib.get('id'), e.text) for e in ET.fromstring(yb).findall('.//{*}Col')]
params = {'HAKBU_GBCD': '0001', 'YEAR': '2026', 'HAKGI': '0002', 'DAEHAK_CD': '%', 'HAKGWA_CD': '%', 'ISU_GBCD': '%',
          'GWAMOK_GBCD': '%', 'GYO_JEON_GBCD': '%', 'GYOGWAMOK_CD': '', 'CHUNGGANG_YN': '%'}
b = p.query(o, 'un/unco/unco07:UNCO0702_S02', params)
root = ET.fromstring(b)
err = [(e.attrib.get('id'), e.text) for e in root.findall('.//{*}Parameter') if e.attrib.get('id') in ('ErrorCode', 'ErrorMsg')]
print('err', err)
rows = []
for ds in root.findall('.//{*}Dataset'):
  print('dataset', ds.attrib.get('id'), len(ds.findall('.//{*}Row')))
  if ds.attrib.get('id') == 'fsp_ds_cmd': continue
  for r in ds.findall('.//{*}Row'):
    rows.append({c.attrib['id']: (c.text or '') for c in r.findall('{*}Col')})
KEEP = ['HAKGWA_CD', 'HAKGWA_NM', 'GYOGWAMOK_CD', 'GYOGWAMOK_NM', 'BUNBAN', 'ISU_GBNM', 'HAKJEOM', 'JUYA_GBNM', 'GWAMOK_GBNM', 'BIGO_GYOSU', 'BIGO_TIME', 'BIGO_GANGUISIL']
cur = {(r['GYOGWAMOK_CD'], r['BUNBAN']): {k: r.get(k, '') for k in KEEP} for r in rows}
prev_rows = json.load(open('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-m/mokpo-2026-2-public-catalog-rows.json'))
prev = {(r['GYOGWAMOK_CD'], r['BUNBAN']): {k: r.get(k, '') for k in KEEP} for r in prev_rows}
changed = [{'id': '-'.join(k), 'before': {f: prev[k][f] for f in KEEP if prev[k][f] != cur[k][f]}, 'after': {f: cur[k][f] for f in KEEP if prev[k][f] != cur[k][f]}} for k in cur.keys() & prev.keys() if prev[k] != cur[k]]
out = {'checkedAt': time.strftime('%Y-%m-%d'), 'entry': p.ENTRY, 'query': 'un/unco/unco07:UNCO0702_S02', 'filters': params,
       'yearHakgi': yr, 'error': err, 'rows': len(rows), 'unique': len(cur), 'prevRows': len(prev),
       'added': sorted('-'.join(k) for k in cur.keys() - prev.keys()), 'removed': sorted('-'.join(k) for k in prev.keys() - cur.keys()),
       'changed': changed}
json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
json.dump(sorted(cur.values(), key=lambda r: (r['GYOGWAMOK_CD'], r['BUNBAN'])), open(sys.argv[2], 'w'), ensure_ascii=False, indent=0)
print({k: v for k, v in out.items() if k not in ('changed',)}, 'changed', len(changed))
