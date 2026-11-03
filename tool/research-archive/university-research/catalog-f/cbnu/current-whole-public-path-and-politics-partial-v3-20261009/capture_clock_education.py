import hashlib
import importlib.util
import json
import pathlib
import urllib.request

out = pathlib.Path(__file__).resolve().parent
root = out.parents[4]
spec = importlib.util.spec_from_file_location('public_hwp', root / 'work/university-research/catalog-g/read_skku_published_office_plan.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
url = 'https://www.chungbuk.ac.kr/www/downloadBbsFile.do?atchmnflNo=361676'
with urllib.request.urlopen(url, timeout=35) as response:
    body = response.read()
    status = response.status
digest = hashlib.sha256(body).hexdigest()
assert digest == '31f1b623fadb84d0aa3ecf2dcda7ff8517afb478247ac7744b3ec4e045203d70'
lines = module.hwp_text(body).splitlines()
indices = [i for i, line in enumerate(lines) if '매요일 0교시' in line]
assert len(indices) == 1
start = indices[0]
fragment = lines[max(0, start - 8):start + 65]
(out / 'current-undergraduate-guide-native-clock-fragment.json').write_text(json.dumps({
    'sourceUrl': url, 'normalStatus': status, 'bytes': len(body), 'sha256': digest,
    'nativeDocumentHeading': lines[0:8],
    'nativeEducationClockLines': fragment,
    'scope': 'Current2026-2 undergraduate guide; exact printed integer0–9, Wednesday/Friday A1–A6 only.',
    'fullGuideSaved': False, 'contactsOrAccountsSaved': False,
}, ensure_ascii=False, indent=2) + '\n')
print('PASS current native clock fragment', len(fragment))
