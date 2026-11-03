"""Recheck the actual public department scope, retaining education fields only."""
import collections
import json
from pathlib import Path
import time
import acquire_hansung as source

ROOT=Path(__file__).resolve().parent
FIELDS=tuple(f for f in source.FIELDS if f != 'plan')

def main():
    departments=source.parse((ROOT/'hansung-departments.xml').read_bytes())
    rows=[];scopes=[]
    for i,item in enumerate(departments.iter('item'),1):
        code,name=item.findtext('tcd'),item.findtext('tnm')
        records=source.parse(source.request({'gubun':'history','syearhakgi':'20262','sjungong':code})).findall('row')
        rows.extend({'departmentCode':code,'departmentName':name,**{f:r.findtext(f,'') for f in FIELDS}} for r in records)
        scopes.append({'departmentCode':code,'departmentName':name,'rows':len(records)})
        if i%20==0: print(f'Current public scope{i} read',flush=True)
        time.sleep(.4)
    old=json.loads((ROOT/'hansung-all-2026-2.json').read_text())
    def identity(r):return(r['departmentCode'],r['kwamokcode'],r['bunban'])
    old={identity(r):{f:r[f] for f in FIELDS} for r in old};new={identity(r):{f:r[f] for f in FIELDS} for r in rows}
    changed=[{'departmentCode':k[0],'courseCode':k[1],'section':k[2],'fields':[f for f in FIELDS if old[k][f]!=new[k][f]]} for k in old.keys()&new.keys() if old[k]!=new[k]]
    audit={'checkedDate':'2026-10-08','scopes':scopes,'wholeCount':len({(r['kwamokcode'],r['bunban']) for r in rows}),'added':[list(k) for k in new.keys()-old.keys()],'removed':[list(k) for k in old.keys()-new.keys()],'changed':changed,'researchOnly':True,'productionReady':False}
    (ROOT/'hansung-current-full-educational-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'hansung-current-full-refresh-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
    print(f"Whole{audit['wholeCount']} added{len(audit['added'])}/removed{len(audit['removed'])}/changed{len(changed)}",flush=True)

if __name__=='__main__':main()
