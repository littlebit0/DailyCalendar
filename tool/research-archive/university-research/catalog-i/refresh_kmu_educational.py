"""Refresh only educational current public fields; no employee IDs or session values persisted."""
import json
from pathlib import Path
import runpy
import time

ROOT = Path(__file__).parent
api = runpy.run_path(str(ROOT / 'collect_kmu_public.py'))
api['op'].open(api['ENTRY'], timeout=30).read()
api['query']('com/MenuCtr/findExMenuOne.do', {'strMenuId': 'M505704'}, menu='', pgm='')
FIELDS = {'yy','tmGbn','scCd','scNm','ltNo','scCdLtNo','deptNm','cptnGbnNm',
    'openHp','hpStr','dayngtGbn','tlsnObjHgCtnt','respProfEmpNm',
    'eduSpaceNm','campGbn','ltTypeGbn','openLtStGbn','openLtClsClssDt',
    'openLtClsClssGbn','openLtClsClssResnCtnt','openLtRemark',
    'lsnTmtablFormaSmryCtnt','genrlCultFldGbnNm','lsnMngtTypeGbnNm','corsGbn'}
rows = {}; scopes = []
for name, table in [('liberal','1'),('major','2')]:
    for scope, first, last in [('weekday','2','7'),('sunday','1','1')]:
        fields = {'yy':'2026','tmGbn':'2','scCd':'','scNm':'','ltTypeGbnSh':'0',
            'campGbn':'','dayngtGbn':'','dayGbnFr':first,'dayGbnTo':last,
            'lectmCdFr':'1','lectmCdTo':'16','cptnGbn':'','univCd':'','colgCd':'',
            'hgCd':'','mjCd':'','tmtblGbn':table,'scheCd':'040521','lsnProgLangGbn':''}
        _, data = api['query']('uni/cour/UnstCtr/findOpenLtCtntInqList.do', fields=fields)
        academic = [r for group in data.values() for r in group if 'scCdLtNo' in r]
        scopes.append({'category':name,'scope':scope,'rows':len(academic)})
        for row in academic:
            cleaned = {key:row.get(key) for key in FIELDS}
            identity = cleaned['scCdLtNo']
            if identity in rows and rows[identity] != cleaned:
                raise ValueError('Conflicting current public academic row')
            rows[identity] = cleaned
        print(name, scope, len(academic), flush=True)
        time.sleep(.8)
result = {'researchOnly':True,'productionReady':False,'completionClaim':False,
    'year':2026,'semester':'2','sourceUrl':api['ENTRY'],'scopes':scopes,
    'records':list(rows.values())}
(ROOT / 'kmu-current-educational-20261007.json').write_text(
    json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('unique current educational rows',len(rows),flush=True)
