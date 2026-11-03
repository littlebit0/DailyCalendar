# -*- coding: utf-8 -*-
import re, json, sys
t = open(sys.argv[1], encoding='utf-8').read()
seg = t[t.find('마이크로디그리 승인 현황'):t.find('기타 마이크로디그리는')]
body = seg.split('주관운영', 1)[1].strip() + ' '
rows = re.findall(r'(\d+) (서울|글로벌) (.+?) (\d+)학점 (.+?)(?= \d+ (?:서울|글로벌) |$)', body)
off = {re.sub(r'\s', '', name): (n, c, name, cr, org.strip()) for n, c, name, cr, org in rows}
print('official rows', len(rows))
camp = {'global': '글로벌', 'seoul': '서울'}
for r in open(sys.argv[2], encoding='utf-8').read().split(', '):
    r = r.strip()
    c, l = r.split(' ', 1)
    name = l.split(' · ', 1)[1]
    o = off.get(re.sub(r'\s', '', name))
    flag = 'MISSING' if not o else ('' if o[1] == camp[c] else 'CAMPUS-DIFF')
    print(r, '=>', o, flag)
json.dump(off, open(sys.argv[3], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
