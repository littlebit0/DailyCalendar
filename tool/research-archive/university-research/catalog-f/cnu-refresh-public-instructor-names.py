"""One normal current public catalog read after plan collector has completed."""
from pathlib import Path
import json,hashlib,collections
R=Path(__file__).resolve().parent
status=json.loads((R/'cnu-current-education-collection-audit.json').read_text())
if not status.get('finished'):
 raise SystemExit('Deferred: plan collector still active; no concurrent request or duplicate collection.')
# Reuse the normal published outlink and codec; this prefix defines send but never runs plan loop.
source=(R/'cnu-current-education-collector.py').read_text();env={"__file__":str(R/'cnu-current-education-collector.py'),"__name__":"cnu_public_name_refresh"}
exec(compile(source[:source.index('query=')],str(R/'cnu-current-education-collector.py'),'exec'),env)
query={'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j,sha=env['send']('Uls0321Service','selectList01',query);rows=j.get('ds_out');assert isinstance(rows,list) and rows
# Immediately project actual public teacher names and permitted educational fields only.
education=[{k:env['clean'](row.get(k)) for k in env['CAT_FIELDS']+['LT_STAFF_NM']} for row in rows];del rows,j
old=json.loads((R/'cnu-current-catalog-education.json').read_text());prior={row['COURSE_NO']:row for row in old};changes=[]
for row in education:
 if row['COURSE_NO'] in prior:
  fields={k:{'prior':prior[row['COURSE_NO']].get(k),'current':row.get(k)} for k in env['CAT_FIELDS'] if prior[row['COURSE_NO']].get(k)!=row.get(k)}
  if fields:changes.append({'courseId':row['COURSE_NO'],'educationalChanges':fields})
ids={row['COURSE_NO'] for row in education}
assert len(ids)==len(education)
env['atomic'](R/'cnu-current-catalog-education-with-public-names.json',education)
env['atomic'](R/'cnu-current-public-name-refresh-audit.json',{'verifiedOn':'2026-10-08','actualCurrentWholeResponseSHA256':sha,'rows':len(education),'namesPresent':sum(bool(x.get('LT_STAFF_NM')) for x in education),'added':sorted(ids-set(prior)),'absent':sorted(set(prior)-ids),'changedSelectedEducationFields':changes,'exactComparedFieldWhitelist':env['CAT_FIELDS'],'publicInstructorNameField':'LT_STAFF_NM','staffIdentifiersPersisted':False,'rawBodyPersisted':False,'contactFieldsPersisted':False,'sessionStatePersisted':False,'fullRecollectionOfPlansPerformed':False,'fullUniversitySupportClaim':False})
print('public name projection',len(education),'namepresent',sum(bool(x.get('LT_STAFF_NM')) for x in education),'educationchanged',len(changes))
