"""Re-count the current KMU public 2026-2 offering list (same published form request as catalog-i)."""
import json, runpy, time, sys
from pathlib import Path
api = runpy.run_path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-i/collect_kmu_public.py')
OUT = Path(sys.argv[1])
api['op'].open(api['ENTRY'], timeout=30).read()
api['query']('com/MenuCtr/findExMenuOne.do', {'strMenuId': 'M505704'}, menu='', pgm='')
rows = {}; scopes = []
for name, table in [('liberal', '1'), ('major', '2')]:
    for scope, first, last in [('weekday', '2', '7'), ('sunday', '1', '1')]:
        time.sleep(0.8)
        fields = {'yy':'2026','tmGbn':'2','scCd':'','scNm':'','ltTypeGbnSh':'0','campGbn':'','dayngtGbn':'',
                  'dayGbnFr':first,'dayGbnTo':last,'lectmCdFr':'1','lectmCdTo':'16','cptnGbn':'','univCd':'',
                  'colgCd':'','hgCd':'','mjCd':'','tmtblGbn':table,'scheCd':'040521','lsnProgLangGbn':''}
        _, data = api['query']('uni/cour/UnstCtr/findOpenLtCtntInqList.do', fields=fields)
        academic = [r for g in data.values() for r in g if 'scCdLtNo' in r]
        scopes.append({'category': name, 'scope': scope, 'rows': len(academic)})
        for r in academic:
            rows.setdefault(r['scCdLtNo'], {k: r.get(k) for k in ('scCdLtNo','scNm','deptNm','campGbn','cptnGbnNm',
                'lsnTmtablFormaSmryCtnt','openLtStGbn','openLtClsClssDt','openLtRemark','tlsnObjHgCtnt','ltTypeGbn')})
        print(name, scope, len(academic), flush=True)
OUT.write_text(json.dumps({'checkedAt': time.strftime('%Y-%m-%d'), 'sourceUrl': api['ENTRY'], 'scopes': scopes,
                           'records': list(rows.values())}, ensure_ascii=False, indent=1))
print('unique', len(rows))
