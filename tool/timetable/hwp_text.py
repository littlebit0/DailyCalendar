"""Minimal stdlib HWP 5.0 text reader (data only, no macros or scripts).

Reads the Compound File Binary container, inflates BodyText/Section*
streams (raw deflate when FileHeader says compressed) and returns the
HWPTAG_PARA_TEXT (tag 67) records as UTF-16LE text with control
characters removed.
"""

import struct
import zlib

FREESECT, ENDOFCHAIN = 0xFFFFFFFF, 0xFFFFFFFE


def _streams(data):
    if data[:8] != b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1':
        raise ValueError('not a CFB file')
    sector_shift, mini_shift = struct.unpack_from('<HH', data, 30)
    ssize, msize = 1 << sector_shift, 1 << mini_shift
    num_fat, first_dir, _, mini_cutoff, first_mini_fat, num_mini_fat, first_difat, num_difat = (
        struct.unpack_from('<IIIIIIII', data, 44))

    def sector(i):
        off = (i + 1) * ssize
        return data[off:off + ssize]

    difat = list(struct.unpack_from('<109I', data, 76))
    d = first_difat
    for _ in range(num_difat):
        if d in (FREESECT, ENDOFCHAIN):
            break
        vals = struct.unpack('<%dI' % (ssize // 4), sector(d))
        difat.extend(vals[:-1])
        d = vals[-1]
    fat = []
    for s in difat[:num_fat]:
        fat.extend(struct.unpack('<%dI' % (ssize // 4), sector(s)))

    def chain(start, table):
        out, seen = [], set()
        while start not in (FREESECT, ENDOFCHAIN) and start < len(table):
            if start in seen:
                raise ValueError('CFB chain loop')
            seen.add(start)
            out.append(start)
            start = table[start]
        return out

    def read(start):
        return b''.join(sector(s) for s in chain(start, fat))

    dirs = read(first_dir)
    entries = []
    for off in range(0, len(dirs) - 127, 128):
        e = dirs[off:off + 128]
        nlen = struct.unpack_from('<H', e, 64)[0]
        name = e[:max(nlen - 2, 0)].decode('utf-16le', 'replace')
        typ = e[66]
        left, right, child = struct.unpack_from('<III', e, 68)
        start, size = struct.unpack_from('<IQ', e, 116)
        entries.append(dict(name=name, type=typ, left=left, right=right,
                            child=child, start=start, size=size))
    root = entries[0]
    ministream = read(root['start'])
    minifat = []
    for s in chain(first_mini_fat, fat):
        minifat.extend(struct.unpack('<%dI' % (ssize // 4), sector(s)))

    def content(e):
        if e['size'] < mini_cutoff:
            raw = b''.join(ministream[s * msize:(s + 1) * msize]
                           for s in chain(e['start'], minifat))
        else:
            raw = read(e['start'])
        return raw[:e['size']]

    out = {}

    def walk(idx, prefix):
        if idx in (FREESECT, 0xFFFFFFFF) or idx >= len(entries):
            return
        e = entries[idx]
        walk(e['left'], prefix)
        walk(e['right'], prefix)
        path = prefix + e['name']
        if e['type'] == 2:
            out[path] = content(e)
        elif e['type'] == 1:
            walk(e['child'], path + '/')

    walk(root['child'], '')
    return out


def _hwpx_paragraphs(data):
    import io
    import re
    import zipfile
    from xml.etree import ElementTree
    out = []
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        names = sorted((n for n in z.namelist() if re.fullmatch(r'Contents/section\d+\.xml', n)),
                       key=lambda n: int(re.search(r'\d+', n).group()))
        for name in names:
            root = ElementTree.fromstring(z.read(name))
            for p in root.iter():
                if p.tag.endswith('}p'):
                    # Direct runs only; nested table paragraphs are visited on their own.
                    text = ''.join(t.text or '' for run in p if run.tag.endswith('}run')
                                   for t in run if t.tag.endswith('}t'))
                    out.append(text)
    return out


def paragraphs(data):
    if data[:4] == b'PK\x03\x04':
        return _hwpx_paragraphs(data)
    streams = _streams(data)
    header = streams.get('FileHeader', b'')
    compressed = len(header) > 36 and (struct.unpack_from('<I', header, 36)[0] & 1)
    sections = sorted((k for k in streams if k.startswith('BodyText/Section')),
                      key=lambda k: int(k[len('BodyText/Section'):]))
    result = []
    for name in sections:
        body = streams[name]
        if compressed:
            body = zlib.decompress(body, -15)
        i = 0
        while i + 4 <= len(body):
            h = struct.unpack_from('<I', body, i)[0]
            tag, size = h & 0x3FF, (h >> 20) & 0xFFF
            i += 4
            if size == 0xFFF:
                size = struct.unpack_from('<I', body, i)[0]
                i += 4
            rec = body[i:i + size]
            i += size
            if tag == 67:
                result.append(_text(rec))
    return result


def _text(rec):
    chars = struct.unpack('<%dH' % (len(rec) // 2), rec[:len(rec) // 2 * 2])
    out, j = [], 0
    while j < len(chars):
        c = chars[j]
        if c < 32:
            # Extended/inline controls occupy 8 UTF-16 units; char controls one.
            if c in (0, 10, 13, 24, 25, 26, 27, 28, 29, 30, 31):
                if c in (10, 13):
                    out.append('\n')
                j += 1
            else:
                j += 8
            continue
        out.append(chr(c))
        j += 1
    return ''.join(out)


if __name__ == '__main__':
    import sys
    with open(sys.argv[1], 'rb') as f:
        for p in paragraphs(f.read()):
            print(p)
