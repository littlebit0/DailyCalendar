import json, sys, hashlib
sys.path.insert(0, sys.argv[1])
from sogang_curl_client import CurlClient
from pathlib import Path
out = Path(sys.argv[2]); out.mkdir(exist_ok=True)
wanted = sys.argv[3].split(',')
c = CurlClient(out / 'jar-plans.txt')
log = {}
for code in dict.fromkeys(w.split('-')[0] for w in wanted):
    res = c.course(code)
    for rec, button in res:
        k = rec['subjectCode'] + '-' + rec['section']
        if k not in wanted:
            continue
        entry = {'row': rec}
        if button:
            pdf, err = c.plan_pdf(button)
            if pdf:
                (out / (k + '.pdf')).write_bytes(pdf)
                entry['sha256'] = hashlib.sha256(pdf).hexdigest()
            else:
                entry['gap'] = err
            c.close_plan()
        else:
            entry['gap'] = 'no syllabus button'
        log[k] = entry
        print(k, entry.get('sha256', entry.get('gap')), flush=True)
missing = [w for w in wanted if w not in log]
print('missing', missing, 'requests', c.count)
(out / 'fetch-log.json').write_text(json.dumps({'checkedAt': '2026-10-23', 'entries': log, 'missing': missing}, ensure_ascii=False, indent=1))
