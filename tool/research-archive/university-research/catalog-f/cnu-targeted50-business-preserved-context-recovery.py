"""Read only50 proposed public plans; project education with token-only redaction."""
import hashlib
import json
import re
from pathlib import Path
from cnu_education_token_cleaner_algorithm_context_v2 import clean as token_clean, COUNTS
R = Path(__file__).resolve().parent
code = (R/'cnu-current-education-collector.py').read_text()
exec(code[:code.index("query={'ORGN_CLSF_CD'")], globals())
# Keep the published normal anonymous transport; replace projection only.
clean = token_clean
candidate_name = 'cnu-unknown-2026-2.whole-checkpoint-next654-preserved-education-v1.json'
candidate = json.loads((R/candidate_name).read_text())
selected = json.loads((R/'cnu-proposed50-business-current-public-plan-context-selection.json').read_text())['courseIds']
assert len(selected) == 50 and len(set(selected)) == 50
D = R/'cnu-proposed50-business-current-recovered-education-20261008'
D.mkdir(exist_ok=True)
query = {'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j, catalogsha = send('Uls0321Service','selectList01',query)
current = {r['COURSE_NO']:r for r in j['ds_out']}
del j
oldcatalog = {r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
status = {'candidate':candidate_name,'candidateSHA256':hashlib.sha256((R/candidate_name).read_bytes()).hexdigest(),'targetPlans':50,'processedPlans':0,'currentCatalogResponseSHA256':catalogsha,'normalPublicRequestOnly':True,'sourceResponseOrStaffIDsOrAnonymousStatePersisted':False,'tokenOnlyContactAndAccessReplacement':True,'scope':'Proposed50 reviewed regular plans only, not production approved, educational whitelist; preserves adjacent teaching text. Existing canonical cache and candidates untouched.','finished':False,'results':[]}
try:
    for cid in selected:
        row = current[cid]
        if str(row.get('CLOSE_YN')) != '0' or str(row.get('OPEN_YR')) != '2026' or row.get('OPEN_SHTM_CD') != 'USR01.20':
            raise GuardStop('current public course identity/closure changed')
        if not row.get('LT_STAFF_NO'):
            raise GuardStop('normal current popup staff field absent; no guessed field')
        file = D/f'{cid}.json'
        if file.exists() and (cid != '1164-3016-00' or json.loads(file.read_text()).get('algorithmSubjectContextPreserved')):
            fresh = json.loads(file.read_text())
            assert fresh['recoveryMethod'] == 'educationTokenOnlyRedactionActualHtmlOnly'
        else:
            data, digest = send('Uls0604Service','selectTab01List',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS})
            if not data.get('ds_out01'):
                raise GuardStop('current public plan now absent')
            fresh = {'biographyEducationBoundaryChecked':True,'algorithmSubjectContextPreserved':True,'courseId':cid,'sourceService':'Uls0604Service/selectTab01List','verifiedOn':'2026-10-08','sourceResponseSHA256':digest,'recoveryMethod':'educationTokenOnlyRedactionActualHtmlOnly','header':[{k:token_clean(h[k]) for k in PLAN_FIELDS if h.get(k) is not None} for h in data['ds_out01']],'weeks':[{k:token_clean(w[k]) for k in WEEK_FIELDS if w.get(k) is not None} for w in data.get('ds_out02',[])]}
            del data
            for section in ['header','weeks']:
                for item in fresh[section]:
                    for k,v in item.items():
                        if isinstance(v,str) and re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|https?://|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',v,re.I):
                            raise GuardStop('residual sensitive value; no educational field persisted')
            atomic(file,fresh)
        old = json.loads((R/'cnu-current-education'/f'{cid}.json').read_text())
        changed = []
        for section in ['header','weeks']:
            for i in range(max(len(old[section]),len(fresh[section]))):
                x = old[section][i] if i < len(old[section]) else {}
                y = fresh[section][i] if i < len(fresh[section]) else {}
                for k in sorted(set(x)|set(y)):
                    if x.get(k) != y.get(k):
                        changed.append({'section':section,'row':i,'field':k})
        catalogchanged = [k for k in CAT_FIELDS+['LT_STAFF_NM'] if token_clean(row.get(k)) != oldcatalog[cid].get(k)]
        status['results'].append({'courseId':cid,'currentResponseSHA256':fresh['sourceResponseSHA256'],'recoveredEducationFieldChanges':changed,'publicCatalogChangedFields':catalogchanged,'newFieldTeachingWeeks':[w['WKORD'] for w in fresh['weeks'] if str(w.get('CLS_METHOD_FIELD',0))=='1'],'currentSceneHours':[h.get('LSN_MTHD_SCENE') for h in fresh['header'] if h.get('LSN_MTHD_SCENE') not in [None,0,'0','']]})
        status['processedPlans'] = len(status['results'])
        status['redactionCounts'] = dict(COUNTS)
        atomic(R/'cnu-proposed50-business-current-preserved-context-recovery-audit.json',status)
        if status['processedPlans']%20 == 0:
            print('50-plan education recovery',status['processedPlans'],'changed-fields',sum(len(x['recoveredEducationFieldChanges']) for x in status['results']),flush=True)
except Exception as e:
    status.update(stopped=True,stopCourseId=cid if 'cid' in globals() else None,stopType=type(e).__name__,stopReason=str(e) if isinstance(e,(GuardStop,ValueError)) else 'bounded public read failure; raw content not printed')
    atomic(R/'cnu-proposed50-business-current-preserved-context-recovery-audit.json',status)
    print('STOP public recovery',status['processedPlans'],status['stopType'],flush=True)
    raise SystemExit(1)
status.update(finished=True,allRecoveredDifferencesSemanticallyReviewed=False)
atomic(R/'cnu-proposed50-business-current-preserved-context-recovery-audit.json',status)
print('finished50 recovery',status['processedPlans'],'changed-courses',sum(bool(x['recoveredEducationFieldChanges']) for x in status['results']),flush=True)
