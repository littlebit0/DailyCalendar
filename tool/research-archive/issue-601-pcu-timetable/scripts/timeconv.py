import re, unicodedata
DAYS = '월화수목금토일'
NUM = {n: (480 + 60 * n, 530 + 60 * n) for n in range(0, 14)}  # 0교시 08:00, 1교시 09:00 ... 13교시 21:00
LET = {'Z': (490, 565), 'A': (570, 645), 'B': (660, 735), 'C': (810, 885), 'D': (900, 975),
       'E': (990, 1065), 'F': (1080, 1155), 'G': (1170, 1245), 'H': (1260, 1335)}

def nfkc(s):
    return unicodedata.normalize('NFKC', s or '')

def slots_std(t):
    """'월A,수B' / '월13,월14' -> [(day, period)] or None if not standard (each token has its own weekday)."""
    t = nfkc(t)
    if not re.fullmatch(r'([월화수목금토일](\d{1,2}|[A-HZ]))(,[월화수목금토일](\d{1,2}|[A-HZ]))*', t):
        return None
    return [(DAYS.index(tok[0]) + 1, tok[1:]) for tok in t.split(',')]

def slots_shared(t):
    """공유혁신 table '강의실및강의시간': 'P408월(D)|P408화(C)' (whitespace removed)."""
    t = nfkc(t)
    out = []
    for seg in t.split('|'):
        m = re.fullmatch(r'([A-Z]{1,3}\d{2,4}(?:-\d)?)([월화수목금토일])\(((?:\d{1,2}|[A-HZ])(?:,(?:\d{1,2}|[A-HZ]))*)\)', seg)
        if not m:
            return None
        for p in m.group(3).split(','):
            out.append((DAYS.index(m.group(2)) + 1, p, m.group(1)))
    return out

def meetings(slots, room):
    """Merge consecutive numeric periods on the same day; letter periods stay separate (existing pcu rule)."""
    res = []
    for s in slots:
        day, p = s[0], s[1]
        r = s[2] if len(s) > 2 else room
        if p.isdigit():
            n = int(p)
            if n not in NUM:
                return None
            st, en = NUM[n]
            if res and res[-1]['_num'] is not None and res[-1]['weekday'] == day and res[-1]['_num'] == n - 1 and res[-1]['classroom'] == r:
                res[-1]['endMinute'] = en; res[-1]['_num'] = n
                continue
            res.append({'weekday': day, 'startMinute': st, 'endMinute': en, 'classroom': r, '_num': n})
        else:
            st, en = LET[p]
            res.append({'weekday': day, 'startMinute': st, 'endMinute': en, 'classroom': r, '_num': None})
    for m in res:
        del m['_num']
    return res
