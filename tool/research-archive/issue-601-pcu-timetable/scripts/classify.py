import json, collections, sys
sys.path.insert(0, 'scripts')
from timeconv import *
UNTIMED = {'온라인', 'X', '미배정'}

def listing_slots(l):
    t = l['time']
    if t is None:
        return ('notime', None)
    t = nfkc(t)
    if t == '' or t == '-':
        # blank time cell; room cell may say 온라인
        return ('online', None) if nfkc(l['room'] or '') == '온라인' else ('blank', None)
    if t in UNTIMED:
        return ('untimed:' + t, None)
    s = slots_shared(t) if l['room'] is None else slots_std(t)
    if s is None:
        return ('nonstd', t)
    return ('slots', frozenset((d, p) for d, p, *_ in s))

def decide(L):
    """Return (status, reason, primary_listing_for_time)."""
    kinds = [listing_slots(l) for l in L]
    slotsets = {v for k, v in kinds if k == 'slots'}
    timed = [l for l, (k, v) in zip(L, kinds) if k == 'slots']
    untimed = {k for k, v in kinds if k.startswith('untimed') or k in ('online', 'notime')}
    nonstd = [v for k, v in kinds if k == 'nonstd']
    if len(slotsets) > 1:
        return 'unrecognized', '원문 간 요일·교시 불일치', None
    if slotsets and untimed - {'notime'}:
        return 'unrecognized', '원문 간 불일치(온라인·미배정과 요일·교시)', None
    if slotsets and any(p not in LET and not (p.isdigit() and int(p) in NUM) for ss in slotsets for _, p in ss):
        return 'unrecognized', '공식 수업 시간표에 없는 교시(14교시)', None
    if slotsets:
        # a non-standard listing is confirmed only when its own reading is not needed:
        # another official listing states the same course with explicit weekday per period.
        return 'scheduled', ('비표준 표기, 다른 공식 목록의 명시 표기로 확정' if nonstd else ''), timed[0]
    if nonstd:
        return 'unrecognized', '비표준 교시 표기(요일 생략·기타)', None
    return 'unscheduled', '원문에 요일·교시 없음(' + ','.join(sorted({k for k, v in kinds})) + ')', None
