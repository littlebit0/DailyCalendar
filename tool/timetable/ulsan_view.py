"""Parsing and response checks for the Ulsan uwins public timetable view (MCB07S).

An HTTP 200 does not mean the expected page came back: an expired session or a
server error page is also HTTP 200. Every navigation response is therefore
checked for the required form and the requested selections before its option
lists are trusted, so an error page can never read as "this college has no 소속".
"""
import html
import re

P = 'ctl01$CP1$'


def form(s):
    d = {}
    for m in re.finditer(r'<input[^>]*>', s):
        t = m.group(0)
        n = re.search(r'name="([^"]*)"', t)
        if not n:
            continue
        ty = re.search(r'type="([^"]*)"', t)
        if ty and ty.group(1) in ('checkbox', 'radio') and 'checked' not in t:
            continue
        v = re.search(r'value="([^"]*)"', t)
        d[html.unescape(n.group(1))] = html.unescape(v.group(1)) if v else ''
    for m in re.finditer(r'<select[^>]*name="([^"]*)"[^>]*>(.*?)</select>', s, re.S):
        opts = re.findall(r'<option([^>]*)value="([^"]*)"', m.group(2))
        sel = [v for a, v in opts if 'selected' in a] or [v for a, v in opts[:1]]
        d[html.unescape(m.group(1))] = html.unescape(sel[0]) if sel else ''
    return d


def options(s, name):
    m = re.search(r'<select[^>]*name="' + re.escape(name) + r'"[^>]*>(.*?)</select>', s, re.S)
    if not m:
        return []
    return [(html.unescape(v), ' '.join(html.unescape(re.sub('<[^>]+>', '', t)).split()))
            for v, t in re.findall(r'<option[^>]*value="([^"]*)"[^>]*>(.*?)</option>', m.group(1), re.S)]


def check_term(s):
    f = form(s)
    if f.get(P + 'imedYy') != '2026' or f.get(P + 'ddlHaggi') != '2':
        raise RuntimeError('term drift')


def check_navigation(s, college, hagbu=None):
    """Raises RuntimeError unless [s] is the 2026-2 view with the requested selections."""
    f = form(s)
    if '__VIEWSTATE' not in f or P + 'ddlDaehag' not in f:
        raise RuntimeError('missing form: not the timetable view')
    check_term(s)
    if not options(s, P + 'ddlDaehag'):
        raise RuntimeError('college list missing')
    if f[P + 'ddlDaehag'] != college:
        raise RuntimeError(f'college selection drift {f[P + "ddlDaehag"]} != {college}')
    if hagbu is not None:
        if not options(s, P + 'ddlHagbu'):
            raise RuntimeError('hagbu list missing')
        if f.get(P + 'ddlHagbu') != hagbu:
            raise RuntimeError(f'hagbu selection drift {f.get(P + "ddlHagbu")} != {hagbu}')


def check_area_view(s, area=None, grade=None):
    """Raises RuntimeError unless [s] is the 2026-2 영역별 (search type 4) view.

    With [area]/[grade] it also checks that the search returned those selections.
    A missing area list must never read as "no areas".
    """
    f = form(s)
    if '__VIEWSTATE' not in f or P + 'ddlSearchType' not in f:
        raise RuntimeError('missing form: not the timetable view')
    check_term(s)
    if f[P + 'ddlSearchType'] != '4':
        raise RuntimeError(f'search type drift {f[P + "ddlSearchType"]} != 4')
    if not options(s, P + 'ddlYeong'):
        raise RuntimeError('area list missing')
    if area is not None and f.get(P + 'ddlYeong') != area:
        raise RuntimeError(f'area selection drift {f.get(P + "ddlYeong")} != {area}')
    if grade is not None and f.get(P + 'ddlHagnyeon') != grade:
        raise RuntimeError(f'grade selection drift {f.get(P + "ddlHagnyeon")} != {grade}')
