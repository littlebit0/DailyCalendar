import io, json, sys, re
from pypdf import PdfReader
from pathlib import Path
d = Path(sys.argv[1]); old = Path(sys.argv[2])
res = {}
for p in sorted(d.glob('*.pdf')):
    k = p.stem
    t = '\n'.join(pg.extract_text() or '' for pg in PdfReader(io.BytesIO(p.read_bytes())).pages)
    o = json.loads((old / (k + '.json')).read_text())
    res[k] = {'oldSha': o.get('fileSha256'), 'text': t}
(d / 'texts.json').write_text(json.dumps(res, ensure_ascii=False))
