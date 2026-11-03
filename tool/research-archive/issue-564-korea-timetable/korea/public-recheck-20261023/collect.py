"""고려대 공개 개설과목 조회를 NetFunnel 대기열을 정상 통과(5101 진입→필요 시 5002 대기→조회→5004 반환)해서 수집한다. HTTP는 curl만 쓴다."""
import json, subprocess, sys, time, urllib.parse, os
OUT = sys.argv[1]
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
NF = 'https://netfunnel.korea.ac.kr/ts.wseq'
REF = 'https://sugang.korea.ac.kr/p/v/lectList?lang=ko'
CJ = os.path.join(OUT, 'cj.txt')
last = [0.0]

def curl(args):
    gap = time.time() - last[0]
    if gap < 1.1: time.sleep(1.1 - gap)
    r = subprocess.run(['curl', '-s', '--max-time', '60', '-A', UA, '-b', CJ, '-c', CJ, '-H', 'Referer: ' + REF] + args, capture_output=True)
    last[0] = time.time()
    return r.stdout.decode('utf-8')

def parse_nf(s):
    code, _, rest = s.strip().partition(':')
    code = code.split(':')[-1]
    parts = s.strip().split(':', 2)
    q = dict(urllib.parse.parse_qsl(parts[2] if len(parts) > 2 else parts[-1]))
    return int(parts[1]) if len(parts) > 2 else int(parts[0]), q

def nf_enter():
    s = curl([NF + '?opcode=5101&sid=service_1&aid=sugang_search'])
    code, q = parse_nf(s)
    while code == 201:  # 대기: 서버가 준 ttl 간격으로 대기 상태만 확인
        time.sleep(max(1, int(q.get('ttl', '1') or 1)))
        s = curl([NF + '?' + urllib.parse.urlencode({'opcode': '5002', 'key': q['key'], 'sticky': q.get('sticky', '')})])
        code, q2 = parse_nf(s); q.update(q2)
    if code != 200: raise RuntimeError('netfunnel ' + s[:200])
    return q

def nf_return(q):
    curl([NF + '?' + urllib.parse.urlencode({'opcode': '5004', 'key': q['key'], 'sticky': q.get('sticky', '')})])

def search(form):
    q = nf_enter()
    try:
        body = curl(['-H', 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8', '--data', urllib.parse.urlencode(form), 'https://sugang.korea.ac.kr/d/v/lectHakbu?fake=%d' % int(time.time() * 1000)])
    finally:
        nf_return(q)
    return json.loads(body)

combo = json.load(open(os.path.join(OUT, 'combo.json')))['rows']
queries = []
for camp in ['1', '2']:
    for div in ['00', '24', '01', '30', '71']:
        if div in ('00', '24'):
            cols = [c for c in combo['allCombos'] if c['DIV'] == 'COL' and c['CAMP'] == camp and div in c['COUR_DIV'].split('^')]
            for c in cols:
                for d in [x for x in combo['allCombos'] if x['DIV'] == 'DPT' and x['UP_CD'] == c['CD'] and x['CAMP'] == camp and div in x['COUR_DIV'].split('^')]:
                    queries.append((camp, div, {'pCol': c['CD'], 'pDept': d['CD']}, c['KO'] + '/' + d['KO']))
        elif div == '01':
            for g in [x for x in combo['allLectures'] if x['CAMP'] == camp]:
                queries.append((camp, div, {'pGroupCd': g['CD']}, g['KO']))
        else:
            queries.append((camp, div, {}, ''))
print(len(queries), 'queries', flush=True)
res_path = os.path.join(OUT, 'results.jsonl')
done = set()
if os.path.exists(res_path):
    for line in open(res_path):
        done.add(json.loads(line)['qid'])
with open(res_path, 'a') as f:
    for camp, div, extra, label in queries:
        qid = '|'.join([camp, div, extra.get('pCol', ''), extra.get('pDept', ''), extra.get('pGroupCd', '')])
        if qid in done: continue
        form = {'pYear': '2026', 'pTerm': '2R', 'pCampus': camp, 'pGradCd': '0136', 'pCourDiv': div}
        form.update(extra)
        form.update({'pCredit': '', 'pDay': '', 'pStartTime': '', 'pEndTime': '', 'pProf': '', 'pCourCd': '', 'pCourNm': '', 'strYear': '2026', 'strTerm': '2R'})
        r = search(form)
        rows = r.get('data') if isinstance(r, dict) and 'data' in r else r.get('rows') if isinstance(r, dict) else r
        f.write(json.dumps({'qid': qid, 'label': label, 'form': form, 'capturedAt': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'code': r.get('code') if isinstance(r, dict) else None, 'message': r.get('message') if isinstance(r, dict) else None, 'rows': rows}, ensure_ascii=False) + '\n'); f.flush()
        print(qid, label, len(rows) if isinstance(rows, list) else rows, flush=True)
        if len(sys.argv) > 2 and sys.argv[2] == 'one': break
