"""Retain educational operating evidence, not complete syllabus curricula."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
scope={'__file__':str(ROOT/'gate_hufs_pending_operating_review.py')}
exec((ROOT/'gate_hufs_pending_operating_review.py').read_text().split('decisions=[]')[0],scope)
match_tags=scope['match_tags'];nonoperating=scope['nonoperating']
extra=r'중간.{0,8}(?:시험|고사)|기말.{0,8}(?:시험|고사)|(?i:mid[ -]?term|final[ -]?(?:exam|test)|exam(?:ination)?|no[ -]?class|holiday|Chuseok|Hange?ul|physical|face.to.face|in.person)|추석|한글날|개천절|대체휴|공휴|대면|장소\s*[:：]|강의실'
summary={'researchOnly':True,'completionClaim':False,'checkedDate':'2026-10-08','plans':0,'originalCharacters':0,'retainedCharacters':0,'publishedMetadataPreserved':True,'fullCurricularSyllabiRetained':False}
def reduce(text,weekly=False):
    selected=[]
    for raw in text.splitlines():
        line=raw.strip()
        if not line or line in nonoperating:continue
        if match_tags(line) or re.search(extra,line):selected.append(line)
    # Keep the existence of a published week. Blank curriculum must not turn an
    # undated final week into an absent week in a dated-normalization pass.
    return '\n'.join(selected) if selected else ('[공개 주차: 별도 확정 운영 날짜 없음]' if weekly and text.strip() else '')
for path in sorted((ROOT/'hufs-public-operating-plans').glob('*.json')):
    doc=json.loads(path.read_text());fields=doc['fields']
    doc.setdefault('publicPlanMetadataStatus','published' if any(fields.get(k) for k in ['methods','notes']) or any(fields.get('weekly',{}).values()) else 'unpublished')
    for name in ['methods','notes']:
        text=fields.get(name,'');summary['originalCharacters']+=len(text);fields[name]=reduce(text);summary['retainedCharacters']+=len(fields[name])
    for key,text in list(fields.get('weekly',{}).items()):
        summary['originalCharacters']+=len(text);fields['weekly'][key]=reduce(text,weekly=True);summary['retainedCharacters']+=len(fields['weekly'][key])
    doc['educationalEvidenceBoundary']='metadata and operating/date/delivery/location evidence only; curricular-only text removed; no full syllabus'
    path.write_text(json.dumps(doc,ensure_ascii=False,indent=2));summary['plans']+=1
(ROOT/'hufs-operating-evidence-minimization-audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(summary)
