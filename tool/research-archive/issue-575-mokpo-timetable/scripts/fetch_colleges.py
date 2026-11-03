import urllib.request, json, time, re, html, sys
UA = 'Mozilla/5.0 (compatible; DailyCalendar/1.0)'
OUT = '/Users/kimhwi/Documents/Codex/DailyCalendar/work/issue-575-mokpo-timetable/colleges/'
def get(url, data=None):
    req = urllib.request.Request(url, data=data, headers={'User-Agent': UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r: return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, e.read()
    except Exception as e: return 0, str(e).encode()
log = {}
for host in sys.argv[1:]:
    s, b = get(f'https://{host}/robots.txt'); time.sleep(0.6)
    rob = b.decode('utf-8', 'replace')
    entry = {'robotsStatus': s, 'robots': rob[:500] if s == 200 else None}
    if s == 200 and re.search(r'(?im)^\s*disallow:\s*/\s*$', rob):
        entry['skipped'] = 'robots disallow /'; log[host] = entry; continue
    s, b = get(f'https://{host}/mokpoDomain/domainChk.do', data=b''); time.sleep(0.6)
    try: site = json.loads(b)['siteId']
    except Exception: site = f'https://{host}/'
    s, b = get(site); time.sleep(0.6)
    entry.update(site=site, status=s, bytes=len(b))
    open(OUT + host + '.html', 'wb').write(b)
    t = re.sub(r'(?s)<script.*?</script>|<style.*?</style>', '', b.decode('utf-8', 'replace'))
    L = [l.strip() for l in html.unescape(re.sub(r'<[^>]+>', '\n', t)).split('\n') if l.strip()]
    open(OUT + host + '.txt', 'w').write('\n'.join(L))
    log[host] = entry
json.dump(log, open(OUT + 'fetch-log.json', 'a'), ensure_ascii=False, indent=1)
print(json.dumps(log, ensure_ascii=False, indent=1))
