import sys, json, collections, zipfile, re
import xml.etree.ElementTree as ET
xlsx, wt = sys.argv[1], sys.argv[2]
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
z = zipfile.ZipFile(xlsx)
ss = []
if 'xl/sharedStrings.xml' in z.namelist():
    for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS):
        ss.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
sheets = sorted(n for n in z.namelist() if re.match(r'xl/worksheets/sheet\d+\.xml', n))
def col(ref):
    n = 0
    for ch in re.match(r'[A-Z]+', ref).group():
        n = n * 26 + ord(ch) - 64
    return n - 1
for sh in sheets:
    rows = []
    for r in ET.fromstring(z.read(sh)).iter('{%s}row' % NS['m']):
        vals = {}
        for c in r.findall('m:c', NS):
            v = c.find('m:v', NS); t = c.get('t')
            if t == 'inlineStr':
                val = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['m']))
            elif v is None: val = None
            elif t == 's': val = ss[int(v.text)]
            else: val = v.text
            vals[col(c.get('r'))] = val
        rows.append([vals.get(i) for i in range(max(vals) + 1)] if vals else [])
    print(sh, len(rows))
    for r in rows[:3]: print(r)
    hdr_i = next(i for i, r in enumerate(rows) if r and any(str(c or '').strip() == '강좌번호' for c in r))
    hdr = [str(c or '').strip() for c in rows[hdr_i]]
    data = [dict(zip(hdr, r)) for r in rows[hdr_i + 1:] if r and any(c not in (None, '') for c in r)]
    print('data rows', len(data)); print(hdr)
    statcol = [h for h in hdr if '폐강' in h or '개설' in h or '여부' in h or '상태' in h]
    print('status cols', statcol)
    print(collections.Counter((d.get("캠퍼스"), d.get("개폐 여부")) for d in data))
    xs = {str(d['강좌번호']).split('.')[0]: d for d in data}
    ds = {}
    for camp in ['daejeon', 'sejong']:
        j = json.load(open(f'{wt}/assets/timetable/hanbat-{camp}-2026-2.json'))
        for c in j['courses']:
            ds[str(c['metadata']['originalEducationalFields']['nativeLectureId'])] = (camp, c)
    print('xlsx ids', len(xs), 'dataset ids', len(ds), 'missing', sorted(set(xs) - set(ds))[:20], 'extra', sorted(set(ds) - set(xs))[:20])
    diffs = collections.Counter()
    for k, d in xs.items():
        if k not in ds: continue
        c = ds[k][1]; f = c['metadata']['originalEducationalFields']
        for h in hdr:
            v = d.get(h)
            if v is None: continue
            vs = str(v).strip()
            if h == '시간' or '시간' in h and '강의' in h:
                if vs != (c['sourceSchedule'] or '').strip(): diffs[h] += 1
        if str(d.get('캠퍼스')).strip() != f['campus']: diffs['campus'] += 1
    print('diffs', diffs)
