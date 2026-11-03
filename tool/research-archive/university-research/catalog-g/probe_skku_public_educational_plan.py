"""Normal outsider form actions only; no contacts or internal identity persistence."""
import json,time
from skku_public import Public,P
class NoSavePublic(Public):
    def post(self,path,params,name,datasets=None,save=False):
        return super().post(path,params,name,datasets,save=False)
FIELDS=('GAESUL_YEAR','GAESUL_TERM','HAKSU_NO','BUNBAN','HAKSU_NM_NO','GAESUL_CAMPUS_GB','PER_NAME','SUUP_YOIL_GYOSI','SUUP_GANGUISIL','ISU_NM','SUGANGDAESANG_HAKGWA','PRE_HAKSU_NAME','CLASS_INFO','BIGO','HAKJUM_TIME','INPUT_TYPE_GB','FOREIGNER_GB_NM','SUUP_TYPE_CD')
def params(code,section,action,out):
    return {'GAESUL_YEAR':'2026','GAESUL_TERM':'20','HAKSU_NO':code,'BUNBAN':section,'_TRANSACTION_ID':action,'_FIRST_OUT_DS_NM':out,'_ALL_OUT_DS_NM':out+'='+out,'_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
if __name__=='__main__':
    p=NoSavePublic('KO');result=[]
    for code,section in [('BIZ2021','01'),('GEDW001','23')]:
        d=p.post('/E_NHSSU900011P/selectMain0',params(code,section,'selectMain0','dsInfoTab01'),'',save=False)
        safe=[{k:r.get(k) for k in FIELDS} for r in d.get('dsInfoTab01',[])];d=None
        item={'code':code,'section':section,'detail':safe,'weekly':[]};time.sleep(.8)
        if safe and safe[0].get('INPUT_TYPE_GB')!='1':
            group=p.post('/E_NHSSU900011P/selectMain01',params(code,section,'selectMain01','dsPlanWeekGb'),'',save=False).get('dsPlanWeekGb',[]);time.sleep(.8)
            weekly=p.post('/E_NHSSU900011P/selectMain3',params(code,section,'selectMain3','dsTab04'),'',save=False).get('dsTab04',[])
            item['weekType']=[r.get('PLAN_WEEK_GB') for r in group]
            item['weekly']=[{k:r.get(k) for k in ('GAESUL_YEAR','GAESUL_TERM','HAKSU_NO','BUNBAN','PLAN_WEEK_GB','PLAN_WEEK_CNT','PLAN_WEEK_CONT','BIGO')}for r in weekly];time.sleep(.8)
        result.append(item)
    (P/'skku-public-educational-plan-probe.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print([(r['code'],r['section'],len(r['detail']),len(r['weekly'])) for r in result])
