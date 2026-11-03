"""Follow the published anonymous entry without persisting session values."""
import html
import http.cookiejar
import json
import re
import urllib.parse
import urllib.request

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
ENTRY = 'https://onestop.kumoh.ac.kr/html/cre/w_cre_s9241_home.html'


def bootstrap():
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def request(url, data=None, referer=''):
        req = urllib.request.Request(url, data=data,
                                     headers={'User-Agent': UA, 'Referer': referer})
        return opener.open(req, timeout=25).read().decode('utf-8', errors='replace')

    entry = request(ENTRY)
    target = re.search(r"URL='([^']+)'", entry).group(1)
    form = request(target, referer=ENTRY)
    action = urllib.parse.urljoin(
        target, re.search(r'<form[^>]*action="([^"]+)"', form).group(1))
    values = {key: html.unescape(value) for key, value in re.findall(
        r'<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"', form)}
    page = request(action, urllib.parse.urlencode(values).encode(), target)
    initial = json.loads(re.search(r'initParameter\((\{.*?\})\)', page).group(1))
    return opener, action, initial


if __name__ == '__main__':
    _, _, initial = bootstrap()
    # Names only. Do not print any bootstrap parameter, cookie, token, or key value.
    print(json.dumps({'success': True, 'parameterNames': list(initial)},
                     ensure_ascii=False, indent=2))
