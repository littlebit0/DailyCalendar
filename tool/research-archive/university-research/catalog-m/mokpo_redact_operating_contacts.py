"""Discard incidental contact strings in otherwise educational note fields."""
import pathlib,json,re,time
P=pathlib.Path(__file__).parent
EMAIL=re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}')
PHONE=re.compile(r'(?<!\d)(?:01[016789][ -]?\d{3,4}[ -]?\d{4}|0[2-8]\d{0,2}[ -]\d{3,4}[ -]\d{4}|\+82[ -](?:10|[2-8]\d?)[ -]\d{3,4}[ -]\d{4})(?!\d)')
def redact(value):
    if isinstance(value,str):return PHONE.sub('[contact omitted]',EMAIL.sub('[contact omitted]',value))
    if isinstance(value,list):return [redact(v) for v in value]
    if isinstance(value,dict):return {k:redact(v) for k,v in value.items()}
    return value

def run(watch=False):
    processed=set();changed=[]
    while True:
        for f in (P/'mokpo-current-plan-operating-20261008').glob('*.json'):
            if f.name in processed:continue
            try:data=json.loads(f.read_text())
            except (json.JSONDecodeError,OSError):continue
            if data.get('operatingSelectionSchema')!=3:continue
            safe=redact(data)
            if safe!=data:
                f.write_text(json.dumps(safe,ensure_ascii=False,indent=2)+'\n');changed.append(f.stem)
            processed.add(f.name)
        if not watch or len(processed)==1307:break
        time.sleep(2)
    (P/'mokpo-current-plan-contact-discard-audit-20261008.json').write_text(json.dumps({'checkedAt':'2026-10-08','educationalPlansChecked':len(processed),'incidentalContactFieldsDiscardedCourseIdentities':changed,'contactTextPersistedInAudit':False},ensure_ascii=False,indent=2)+'\n')
    print('privacy educational plans checked',len(processed),'incidental contact course count',len(changed),flush=True)
if __name__=='__main__':
    import sys;run('--watch' in sys.argv)
