"""One-owner bounded public-print refresh. No raw responses or staff profiles saved."""
import json,time,pathlib,re,xml.etree.ElementTree as ET,urllib.error
import mokpo_public_protocol as protocol
from mokpo_redact_operating_contacts import redact
P=pathlib.Path(__file__).parent
DEST=P/'mokpo-current-plan-operating-20261008';DEST.mkdir(exist_ok=True)
IDS=['un/unco/unco07:UNCO0701_S10','un/unco/unco07:UNCO0701_S11','un/unco/unco07:UNCO0701_S12']
MAIN={'HAKBU_GBCD','YEAR','HAKGI','HAKGWA_CD','HAKNYEON','GYOGWAMOK_CD','BUNBAN','HAKJEOM','ERON_SISU','SILSEUP_SISU','TONGHAB_SISU','ISU_GBNM','BIGO_TIME','BIGO_GANGUISIL','GYOGWAMOK_CD_NM','GYOSU_NM','YUUI_SAHANG'}
WEEK={'JUCHA','YEAR','HAKGI','GYOGWAMOK_CD','BUNBAN','BANGBEOP','BIGO'}
# These are triage markers only. A word mentioning online content or a field trip
# does not establish course mode, changed attendance, or the exact event date.
PAT=re.compile(r'교외교육|방문|답사|견학|캠프|블록|선수|전용|전공생|타학과|수강신청|수강생|학년|eligib|enrol|only|jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|lms|zoom|flipped|휴강|보강|휴일|공휴|요일|월요일|화요일|수요일|목요일|금요일|토요일|일요일|비대면|온라인|원격|동영상|녹화|혼합|블렌디드|집중|현장|견학|실습|선수|수강.{0,8}(제한|불가|대상)|대상.{0,8}학생|\d{1,2}\s*월\s*\d{1,2}\s*일|\d{1,2}[./-]\d{1,2}|\d{1,2}:\d{2}|holiday|make.?up|cancel|reschedul|monday|tuesday|wednesday|thursday|friday|saturday|sunday|online|remote|video|recorded|hybrid|blended|intensive|field.?trip|prerequisit|restricted|eligib',re.I)
def snippets(value):
    if not value:return []
    return [s.strip() for s in re.split(r'[\r\n]+',value) if PAT.search(s)]
def sanitize(root):
    datasets={}
    for ds in root.findall('.//{*}Dataset'):
        name=ds.attrib.get('id')
        if name not in ['ds_out','ds_out3']:continue
        rows=[]
        for rr in ds.findall('.//{*}Row'):
            allvals={v.attrib['id']:v.text for v in rr}
            if name=='ds_out':
                row={k:v for k,v in allvals.items() if k in MAIN and k!='YUUI_SAHANG'}
                row['operatingNoteExcerpts']=[v.strip() for v in (allvals.get('YUUI_SAHANG') or '').splitlines() if v.strip()]
                # Course pedagogy/method fields are educational; preserve only actual
                # operating markers rather than the course overview/profile.
                row['additionalOperatingExcerpts']={k:[line.strip() for line in (v or '').splitlines() if line.strip()] for k,v in allvals.items() if k in ['GYOGWAMOK_GAEYO','GYOYUK_GOAL_1','GYOYUK_GOAL_2','GYOYUK_GOAL_3','GYOYUK_GOAL_4','BUNSEOK_GAESEON_BANGAN'] and v}
            else:
                row={k:v for k,v in allvals.items() if k in WEEK}
                row['operatingContentExcerpts']=[v.strip() for v in (allvals.get('CONTENTS') or '').splitlines() if v.strip()]
                row['operatingAssignmentExcerpts']=[v.strip() for v in (allvals.get('GWAJE') or '').splitlines() if v.strip()]
            rows.append(row)
        datasets[name]=rows
    return redact(datasets)

def run():
    scope=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text())
    original=json.loads((P/'mokpo-2026-2-public-catalog-rows.json').read_text())
    request_rows={(r['GYOGWAMOK_CD'],r['BUNBAN']):r for r in original}
    opener=protocol.bootstrap(); failures=[];saved=0
    for row in scope:
        key=(row['GYOGWAMOK_CD'],row['BUNBAN']);f=DEST/(key[0]+'-'+key[1]+'.json')
        if f.exists() and json.loads(f.read_text()).get('operatingSelectionSchema')==3:continue
        raw=request_rows[key]
        args={k:raw.get(k,'') for k in ['HAKBU_GBCD','YEAR','HAKGI','HAKGWA_CD','HAKNYEON','GYOGWAMOK_CD','BUNBAN','GYOSU_CD','GJ_GBCD']}
        try:
            time.sleep(.4)
            pre=ET.fromstring(protocol.query(opener,'un/unco/unco07:UNCO0710P03_S05',args))
            ec=pre.find('.//{*}Parameter[@id="ErrorCode"]')
            if ec is None or ec.text!='0':raise RuntimeError('public_preflight_error')
            args['CHK_CNT']=str(sum(v.text=='TURE' for v in pre.findall('.//{*}Col[@id="GBN"]')))
            time.sleep(.4)
            current=ET.fromstring(protocol.query(opener,IDS,args))
            ec=current.find('.//{*}Parameter[@id="ErrorCode"]')
            if ec is None or ec.text!='0':raise RuntimeError('public_print_error')
            data=sanitize(current)
            f.write_text(json.dumps({'checkedAt':'2026-10-08','operatingSelectionSchema':3,'requestIdentity':{'year':row['YEAR'],'semester':row['HAKGI'],'courseCode':key[0],'section':key[1]},'source':'official anonymous UNCO04 published preflight/print flow','educationalDatasets':data},ensure_ascii=False,indent=2)+'\n')
            saved+=1
            if saved%25==0:print('fresh educational plans',saved,'retained',len(list(DEST.glob('*.json'))),flush=True)
        except (urllib.error.HTTPError,ET.ParseError,RuntimeError) as error:
            # Never retry protection/error HTML with another identity/route.
            failures.append({'courseCode':key[0],'section':key[1],'reason':type(error).__name__,'httpStatus':getattr(error,'code',None),'stopped':True});break
        except Exception as error:
            failures.append({'courseCode':key[0],'section':key[1],'reason':type(error).__name__,'stopped':True});break
    audit={'checkedAt':'2026-10-08','requested':1307,'freshEducationalFiles':len(list(DEST.glob('*.json'))),'failures':failures,'singleOwner':True,'minimumRequestSpacingSeconds':.4,'rawResponseSaved':False,'staffProfileSaved':False,'completionClaim':False}
    (P/'mokpo-current-plan-operating-refresh-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(audit,flush=True)
if __name__=='__main__':run()
