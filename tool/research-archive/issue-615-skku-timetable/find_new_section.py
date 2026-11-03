"""공식 개설강좌 조회에서 새로 생긴 분반의 전체 행과 조회 학과를 찾는다."""
import json,sys,pathlib,re
sys.argv=[sys.argv[0]]
src=pathlib.Path(__file__).with_name('census_2026_2.py').read_text()
head=src.split("major=json.loads")[0]  # 세션·요청 함수만 재사용
exec(head)
G=pathlib.Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-g')
major=json.loads((G/'skku-ko-major-all-2026-2.json').read_text())
names={r['COM_CD']:r['CD_NM'] for r in json.loads((G/'skku-ko-major-departments.json').read_text())}
TARGET='SWE3043-46';hits=[];row=None
for m in major['index']:
    if m['CAMPUS_GB']!='2':continue
    p={k:m[k] for k in ('YEAR','TERM','HAKGWA_CD','ROAD_MAP','CAMPUS_GB','HAK_JIBJUNG')}
    for r in q('/E_NHSSU900020M','selectMain',p,'dsGrdMain'):
        if r['HAKSU_NO_BUNBAN']==TARGET:
            hits.append({'code':p['HAKGWA_CD'],'name':names.get(p['HAKGWA_CD'])});row={k:v for k,v in r.items() if not re.search('ID$|TEL|MAIL',k)}
pathlib.Path(__file__).with_name('new-section-SWE3043-46.json').write_text(json.dumps({'departments':hits,'row':row},ensure_ascii=False,indent=1))
print(hits,row and row.get('ISU_NAME'))
