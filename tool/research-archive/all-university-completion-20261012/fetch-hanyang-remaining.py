import concurrent.futures
import hashlib
import json
import urllib.request
from pathlib import Path

base = Path('work/all-university-completion-20261012/root-sources')
sources = {
    'hanyang-data-degrees': 'https://hyds.hanyang.ac.kr/front/grs/deg',
    'hanyang-seoul-programs': 'https://academic.hanyang.ac.kr/-10',
    'hanyang-erica-readmission-2026': 'https://site.hanyang.ac.kr/documents/portlet_file_entry/10965283/02.%2B2026-2%ED%95%99%EA%B8%B0%2B%EC%9E%AC%EC%9E%85%ED%95%99%2B%EC%95%88%EB%82%B4%EB%AC%B8%28%ED%95%99%EC%83%9D%2B%EA%B3%B5%EC%A7%80%EC%9A%A9%29.pdf/5af17a10-a6b4-0752-27da-3d29c4ffb2e8?download=true&status=0',
}

def fetch(item):
    name, url = item
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
        path = base / (name + ('.pdf' if data.startswith(b'%PDF') else '.html'))
        path.write_bytes(data)
        return {'url': url, 'file': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    except Exception as error:
        return {'url': url, 'error': str(error)}

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    receipts = list(pool.map(fetch, sources.items()))
(base / 'receipts-hanyang-remaining.json').write_text(json.dumps(receipts, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(receipts, ensure_ascii=False))
