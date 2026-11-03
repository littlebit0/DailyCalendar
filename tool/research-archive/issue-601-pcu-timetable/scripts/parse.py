import fitz, json, re, sys
src, out = sys.argv[1], sys.argv[2]
d = fitz.open(src)
rows = []
carry = None
for pno in range(len(d)):
    page = d[pno]
    if '교과목코드' not in re.sub(r'\s+', '', page.get_text()):
        continue
    tabs = sorted(page.find_tables().tables, key=lambda t: t.bbox[1])
    # text blocks outside tables, for headings
    blocks = [(b[1], b[3], b[0], b[4].strip()) for b in page.get_text('blocks') if b[4].strip()]
    for t in tabs:
        data = t.extract()
        if not data:
            continue
        hdr = [re.sub(r'\s+', '', c or '') for c in data[0]]
        if '교과목코드' not in hdr:
            print('NOHDR', pno + 1, hdr, file=sys.stderr)
            continue
        top = t.bbox[1]
        heads = [b for b in blocks if b[1] <= top + 1]
        heads.sort(key=lambda b: b[0])
        angle = [h[3] for h in heads if h[3].startswith('<')]
        if angle:
            carry = re.sub(r'\s+', '', re.match(r'<([^>]+)>', angle[-1]).group(1))
        for ri, r in enumerate(data[1:]):
            cells = [(c or '').strip() for c in r]
            rows.append({'page': pno + 1, 'table_y': round(top, 1), 'hdr': hdr,
                         'cells': cells, 'heads': [h[3] for h in heads[-4:]], 'heading': carry})
json.dump(rows, open(out, 'w'), ensure_ascii=False, indent=0)
print(len(rows))
