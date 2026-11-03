"""Inspect current private-biography boundary in memory; output structural flags only."""
import hashlib, json, re, html
from pathlib import Path
R=Path(__file__).resolve().parent
source=(R/'cnu-current-education-collector.py').read_text()
exec(source[:source.index("query={'ORGN_CLSF_CD'")],globals())
query={'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j,csha=send('Uls0321Service','selectList01',query);row=next(x for x in j['ds_out'] if x['COURSE_NO']=='1100-7003-03');del j
j,sha=send('Uls0604Service','selectTab01List',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS})
lines=[]
for h in j['ds_out01']:
 for k in PLAN_FIELDS:
  v=h.get(k)
  if not isinstance(v,str):continue
  v=re.sub(r'<(?:br\s*/?|/p|/div|/li)>','\n',v,flags=re.I);v=html.unescape(re.sub('<[^>]*>',' ',v))
  lines.extend((k,line) for line in v.splitlines() if '호적등재오류' in line and '개명' in line)
assert len(lines)==1
field,line=lines[0]
patterns={'lessonOrExamTime':r'수업|휴강|보강|교시|시간표|실습|시험|종강|개강|요일|[0-9]{1,2}[:：][0-9]{2}','offsite':r'야외|교외|현장|견학|탐방|답사|field\s*trip','delivery':r'온라인|원격|비대면|대면|녹화|VOD|Zoom|동영상','sectionRestriction':r'분반|수강|이수|선수|정원|학과|학기|주차|기간'}
flags={k:bool(re.search(p,line,re.I)) for k,p in patterns.items()}
audit={'courseId':'1100-7003-03','sourceResponseSHA256':sha,'field':field,'singlePreviouslyReviewedBiographyLine':True,'operatingSignals':flags,'genericLectureWordPresent':bool(re.search('강의',line)),'privateBiographyOrNamesPersisted':False,'rawResponsePersisted':False,'decision':'pureNoninstructionalBiographyNoOperatingSignals' if not any(flags.values()) else 'biographyBoundaryUnresolvedMustBlock'}
del line,lines,j,row
atomic(R/'cnu-one-biography-education-boundary-proof.json',audit)
print(json.dumps(audit,ensure_ascii=False))
