"""Only two proposed current plans; no full-plan recollection or private fields saved."""
import json,re,hashlib
from pathlib import Path
R=Path(__file__).resolve().parent
source=(R/'cnu-current-education-collector.py').read_text()
# Existing documented normal anonymous outlink + public codec; stops before any catalog loop.
exec(source[:source.index("query={'ORGN_CLSF_CD'")],globals())
query={'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j,catalogsha=send('Uls0321Service','selectList01',query)
current={r['COURSE_NO']:r for r in j['ds_out']};del j
selected=['1004-7003-06','1004-7003-08']
D=R/'cnu-two-proposed-current-education-recheck';D.mkdir(exist_ok=True)
oldcatalog={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
results=[]
for cid in selected:
 row=current[cid]
 if str(row['CLOSE_YN'])!='0':raise GuardStop('proposed course now closed; stop')
 if not row.get('LT_STAFF_NO'):raise GuardStop('current normal published popup staff field absent; no guessed field')
 data,digest=send('Uls0604Service','selectTab01List',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS})
 if not data.get('ds_out01'):raise GuardStop('proposed current public plan absent')
 fresh={'courseId':cid,'sourceService':'Uls0604Service/selectTab01List','verifiedOn':'2026-10-08','sourceResponseSHA256':digest,'header':[{k:clean(h[k]) for k in PLAN_FIELDS if h.get(k) is not None} for h in data.get('ds_out01',[])],'weeks':[{k:clean(w[k]) for k in WEEK_FIELDS if w.get(k) is not None} for w in data.get('ds_out02',[])]}
 # Omit short access/phone tokens, without removing adjacent education.
 for section in ['header','weeks']:
  for h in fresh[section]:
   for k,v in h.items():
    if isinstance(v,str):h[k]=re.sub(r'(?<!\d)\d{3}[- ]\d{4}(?!\d)','[contact removed]',v)
 old=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text())
 changed=[]
 for section in ['header','weeks']:
  olditems=old[section];newitems=fresh[section]
  for i in range(max(len(olditems),len(newitems))):
   a=olditems[i] if i<len(olditems) else {};b=newitems[i] if i<len(newitems) else {}
   for k in sorted(set(a)|set(b)):
    if a.get(k)!=b.get(k):changed.append({'section':section,'row':i,'field':k})
 metadatachanged=[k for k in CAT_FIELDS if clean(row.get(k))!=oldcatalog[cid].get(k)]
 if clean(row.get('LT_STAFF_NM'))!=oldcatalog[cid].get('LT_STAFF_NM'):metadatachanged.append('LT_STAFF_NM')
 atomic(D/f'{cid}.json',fresh);del data
 results.append({'courseId':cid,'currentResponseSHA256':digest,'educationFieldsChanged':changed,'publicCatalogEducationChangedFields':metadatachanged,'currentPlanPresent':True})
 print('current proposed plan checked',len(results),'/',len(selected),'educational difference fields',len(changed),flush=True)
atomic(R/'cnu-two-proposed-current-education-recheck-audit.json',{'verifiedOn':'2026-10-08','targetPlans':2,'processedPlans':len(results),'currentCatalogReadForActualVisibleRequestFieldsOnce':True,'currentCatalogResponseSHA256':catalogsha,'normalRequestsBounded':True,'rawRepliesOrStaffIDsOrAnonymousStateSaved':False,'selectedEducationalWhitelistOnly':True,'improvedContactReplacementPreservesNeighboringEducation':True,'results':results,'wholePlansRecollected':False,'allDifferenceContextsReviewed':False})
