import collections
import hashlib
import json
import pathlib
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib

sys.path.insert(0, '/private/tmp/daily-catalog-xls-read')
import xlrd
from xlrd.compdoc import CompDoc

ROOT = pathlib.Path('work/university-research')
OUT = ROOT / 'catalog-c/three-held-native-embedded-clock-audit-v1-20261009'
HH = re.compile(r'(?<!\d)(?:[01]?\d|2[0-3])\s*[:\uff1a]\s*[0-5]\d(?!\d)')
N = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def xlsx(p):
    result = {'file': str(p), 'sha256': sha(p), 'format': 'OOXML', 'sheets': [], 'clockTextParts': []}
    with zipfile.ZipFile(p) as z:
        names = z.namelist()
        wb = ET.fromstring(z.read('xl/workbook.xml'))
        result['nativeSheetNamesStates'] = [dict(t.attrib) for t in wb.findall('s:sheets/s:sheet', N)]
        result['commentParts'] = [n for n in names if re.search(r'comments\d*\.xml$', n)]
        result['drawingParts'] = [n for n in names if n.startswith('xl/drawings/') and n.endswith('.xml')]
        result['mediaParts'] = [n for n in names if n.startswith('xl/media/')]
        ss = []
        if 'xl/sharedStrings.xml' in names:
            for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si', N):
                ss.append(''.join(si.itertext()))
        st = ET.fromstring(z.read('xl/styles.xml'))
        formats = {int(n.attrib['numFmtId']): n.attrib['formatCode'] for n in st.findall('s:numFmts/s:numFmt', N)}
        xfs = [int(n.attrib.get('numFmtId', 0)) for n in st.findall('s:cellXfs/s:xf', N)]
        result['customNumberFormats'] = formats
        for n in names:
            if not n.endswith('.xml'):
                continue
            raw = z.read(n).decode('utf-8')
            hits = HH.findall(raw)
            if hits:
                result['clockTextParts'].append({'part': n, 'matches': sorted(set(hits))})
            if not re.match(r'xl/worksheets/sheet\d+\.xml$', n):
                continue
            e = ET.fromstring(raw)
            sheet = {'part': n, 'hiddenRows': [], 'hiddenColumns': [], 'mergedRanges': [], 'formulas': [], 'clockCells': [], 'numericTimeFormatCells': [], 'printHeaderFooter': []}
            sheet['hiddenRows'] = [t.attrib for t in e.findall('s:sheetData/s:row', N) if t.attrib.get('hidden') == '1']
            sheet['hiddenColumns'] = [t.attrib for t in e.findall('s:cols/s:col', N) if t.attrib.get('hidden') == '1']
            sheet['mergedRanges'] = [t.attrib['ref'] for t in e.findall('s:mergeCells/s:mergeCell', N)]
            for t in e.findall('s:headerFooter/*', N):
                sheet['printHeaderFooter'].append({'kind': t.tag.rsplit('}', 1)[-1], 'text': t.text or ''})
            for c in e.findall('s:sheetData/s:row/s:c', N):
                v = c.find('s:v', N); value = v.text if v is not None else ''
                if c.attrib.get('t') == 's' and value:
                    value = ss[int(value)]
                if c.attrib.get('t') == 'inlineStr':
                    value = ''.join(c.find('s:is', N).itertext())
                f = c.find('s:f', N)
                if f is not None:
                    sheet['formulas'].append({'cell': c.attrib['r'], 'formula': f.text, 'cachedValue': value})
                if HH.search(value or ''):
                    sheet['clockCells'].append({'cell': c.attrib['r'], 'value': value})
                fmtid = xfs[int(c.attrib.get('s', 0))]
                fmt = formats.get(fmtid, '')
                if value and c.attrib.get('t') not in ('s', 'inlineStr') and (fmtid in (18,19,20,21,22,45,46,47) or re.search(r'[hH].*[mM]', fmt)):
                    sheet['numericTimeFormatCells'].append({'cell': c.attrib['r'], 'value': value, 'formatId': fmtid, 'customFormat': fmt})
            result['sheets'].append(sheet)
    return result

def biff(p):
    book = xlrd.open_workbook(str(p), formatting_info=True)
    d = CompDoc(p.read_bytes()); raw = d.get_named_stream('Workbook')
    result = {'file': str(p), 'sha256': sha(p), 'format': 'BIFF', 'sheets': [], 'recordCounts': {}, 'printHeaderFooterClockHits': [], 'rawClockMatches': []}
    pos = 0; counts = collections.Counter()
    while pos + 4 <= len(raw):
        typ, size = struct.unpack_from('<HH', raw, pos); pos += 4
        b = raw[pos:pos+size]; pos += size; counts[str(typ)] += 1
        if typ in (0x14, 0x15):
            for enc in ('utf-16le', 'latin1'):
                text = b.decode(enc, errors='ignore')
                if HH.search(text):
                    result['printHeaderFooterClockHits'].append({'recordType': typ, 'encoding': enc, 'matches': HH.findall(text)})
    result['recordCounts'] = dict(counts)
    result['embeddedObjectRecordCounts'] = {hex(k): counts[str(k)] for k in (0x5d,0x1b6,0xec,0xeb,0x1c)}
    for enc in ('utf-16le', 'latin1'):
        result['rawClockMatches'].append({'encoding': enc, 'matches': sorted(set(HH.findall(raw.decode(enc, errors='ignore'))))})
    for s in book.sheets():
        o = {'name': s.name, 'visibility': s.visibility, 'mergedRanges': s.merged_cells, 'hiddenRows': [i for i,v in s.rowinfo_map.items() if v.hidden], 'hiddenColumns': [i for i,v in s.colinfo_map.items() if v.hidden], 'clockCells': [], 'numericTimeFormatCells': [], 'comments': len(s.cell_note_map)}
        for row in range(s.nrows):
            for col in range(s.ncols):
                c = s.cell(row,col); fmtid = book.xf_list[s.cell_xf_index(row,col)].format_key
                fmt = book.format_map[fmtid].format_str
                if c.ctype == xlrd.XL_CELL_TEXT and HH.search(c.value):
                    o['clockCells'].append({'row':row,'column':col,'value':c.value})
                if c.ctype == xlrd.XL_CELL_DATE:
                    o['numericTimeFormatCells'].append({'row':row,'column':col,'value':c.value,'format':fmt})
        result['sheets'].append(o)
    return result

def hwp(p):
    d = CompDoc(p.read_bytes())
    r = {'file': str(p), 'sha256': sha(p), 'format': 'HWPv5', 'streams': [{'name':x.name,'type':x.etype,'bytes':x.tot_size} for x in d.dirlist if x.name], 'paragraphClockMatches': [], 'recordCounts': {}, 'embeddedImageNames': [x.name for x in d.dirlist if x.name.startswith('BIN')], 'previewImageClockReviewed': False}
    counts = collections.Counter()
    for sn in range(100):
        b = d.get_named_stream('BodyText/Section'+str(sn))
        if b is None:
            break
        b = zlib.decompress(b, -15); pos = 0
        while pos + 4 <= len(b):
            v = struct.unpack_from('<I', b, pos)[0]; pos += 4; tag = v & 1023; size = v >> 20
            if size == 4095:
                size = struct.unpack_from('<I', b, pos)[0]; pos += 4
            q = b[pos:pos+size]; pos += size; counts[str(tag)] += 1
            if tag == 67:
                text = q.decode('utf-16le', errors='ignore')
                if HH.search(text):
                    r['paragraphClockMatches'].append({'section':sn,'matches':HH.findall(text)})
    r['recordCounts'] = dict(counts)
    preview = d.get_named_stream('PrvImage')
    if preview:
        (OUT/'cje-preview-image.png').write_bytes(preview)
    for name in ('PrvText','DocInfo'):
        b = d.get_named_stream(name)
        if name == 'DocInfo':
            b = zlib.decompress(b,-15)
        r[name+'ClockMatches'] = HH.findall(b.decode('utf-16le',errors='ignore'))
    return r

files = [ROOT/'catalog-g/cnue2026-2-0826.xlsx', ROOT/'catalog-g/cue2026-2-final-files/file0.xlsx']
audit = [xlsx(p) for p in files]
audit += [biff(ROOT/f'catalog-g/cue2026-2-final-files/file{i}.xls') for i in range(1,5)]
audit += [hwp(ROOT/'catalog-g/cje2026-2-final0904.hwp')]
(OUT/'embedded-structure-audit.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'networkRequests':0,'sdkRuns':0,'documents':audit},ensure_ascii=False,indent=2)+'\n')
for o in audit:
    print(o['file'], 'clockCells', sum(len(s['clockCells']) for s in o.get('sheets',[])), 'clockParts', o.get('clockTextParts',[]), 'rawClock', o.get('rawClockMatches',[]), 'paragraphClock', o.get('paragraphClockMatches',[]))
