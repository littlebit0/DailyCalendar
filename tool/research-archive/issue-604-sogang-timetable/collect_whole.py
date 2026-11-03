import json, sys
sys.path.insert(0, sys.argv[1])
from sogang_curl_client import CurlClient, rendered, ENTRY
from pathlib import Path
out = Path(sys.argv[2])
c = CurlClient(out.parent / 'jar-whole.txt')
whole = c.whole()
print('rows', len(whole), 'requests', c.count)
keys = [(r['subjectCode'], r['section']) for r, b in whole]
assert len(keys) == len(set(keys)), 'duplicate keys'
out.write_text(json.dumps({'checkedAt': '2026-10-23', 'sourceUrl': ENTRY, 'division': '대학', 'records': [r for r, b in whole], 'syllabusButton': {r['subjectCode'] + '-' + r['section']: bool(b) for r, b in whole}}, ensure_ascii=False, indent=1) + '\n')
(out.parent / 'whole-response-20261023.xml').write_text(c.response)
