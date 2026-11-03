"""Collect actual public syllabus print datasets through the posted UNCO04 flow.
Two paced anonymous workers; no auth, no extra query IDs, no session persistence.
Faculty contact details are intentionally omitted from research artifacts.
"""
import pathlib,json,concurrent.futures,time,xml.etree.ElementTree as ET
import mokpo_public_protocol as protocol
P=pathlib.Path(__file__).parent
DEST=P/'mokpo-public-plans';DEST.mkdir(exist_ok=True)
ROWS=json.loads((P/'mokpo-2026-2-public-catalog-rows.json').read_text())
IDS=['un/unco/unco07:UNCO0701_S10','un/unco/unco07:UNCO0701_S11','un/unco/unco07:UNCO0701_S12']
FIELDS=['HAKBU_GBCD','YEAR','HAKGI','HAKGWA_CD','HAKNYEON','GYOGWAMOK_CD','BUNBAN','GYOSU_CD','GJ_GBCD']
def worker(rows):
    opener=protocol.bootstrap();count=0;failed=[]
    for r in rows:
        file=DEST/(r['GYOGWAMOK_CD']+'-'+r['BUNBAN']+'.json')
        if file.exists(): continue
        args={k:r.get(k,'') for k in FIELDS}
        # CHK_CNT governs print form; normal public outline preflight returns capability count.
        try:
            pre=ET.fromstring(protocol.query(opener,'un/unco/unco07:UNCO0710P03_S05',args))
            args['CHK_CNT']=str(sum(v.text=='TURE' for v in pre.findall('.//{*}Col[@id="GBN"]')))
            root=ET.fromstring(protocol.query(opener,IDS,args))
            error=root.find('.//{*}Parameter[@id="ErrorCode"]')
            if error is None or error.text!='0':
                failed.append({'course':file.stem,'errorCode':error.text if error is not None else 'missing'});continue
            datasets={}
            for ds in root.findall('.//{*}Dataset'):
                if ds.attrib.get('id')=='fsp_ds_cmd': continue
                datasets[ds.attrib['id']]=[{v.attrib['id']:v.text for v in row if v.attrib['id'] not in ['TEL_NO','EMAIL']} for row in ds.findall('.//{*}Row')]
            file.write_text(json.dumps(datasets,ensure_ascii=False,indent=2));count+=1
            if count%50==0:print('worker saved',count,flush=True)
        except Exception as e:failed.append({'course':file.stem,'errorType':type(e).__name__})
        time.sleep(.4)
    return {'saved':count,'failures':failed}
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
        result=list(ex.map(worker,[ROWS[::2],ROWS[1::2]]))
    (P/'mokpo-public-plan-collection-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print('totalSaved',sum(x['saved'] for x in result),'failures',sum(len(x['failures']) for x in result),flush=True)
