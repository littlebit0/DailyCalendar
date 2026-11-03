import json,re
from pathlib import Path
p=Path(__file__).parent/'kmou-current-new-notices';f='4c440bc0beed854b1d06bf7846bc274e'
x=json.loads((p/(f+'.tables.json')).read_text());receipt=next(r for r in json.loads((p/'download-receipt.json').read_text()) if Path(r['file']).stem==f)
records=[];hold=[];previous=None
for row,r in enumerate(x[0]['tables'][0][2:],2):
 if r[1]:previous=r[:4]
 base={'sourceEducation':{'fileKey':f,'page':1,'table':0,'row':row,'nativeCells':r,'inheritedMergedCourseCells':previous,'sourceUrl':receipt['url'],'noticeUrl':receipt['noticeUrl'],'sha256':receipt['sha256']},'courseCode':previous[1],'courseName':re.sub(r'\s+','',previous[2]),'classification':re.sub(r'\s+','',previous[0]),'credits':float(previous[3].split('/')[0]),'professor':r[6] or '', 'sourceClassroom':r[4] or '', 'departments':['항해융합학부'],'grade':3,'academicYear':2026,'semester':'2','campus':'unknown','scheduleStatus':'unprinted','schedules':[]}
 section=r[5] or ''
 if '택' in section or not section:hold.append(dict(base,section=section,reason='지도교수 또는 여러 실습선에 걸친 실제 개별 분반 지정 불확정'));continue
 if re.fullmatch(r'\d{3}~\d{3}',section):a,b=map(int,section.split('~'));sections=[f'{v:03d}' for v in range(a,b+1)]
 else:sections=re.findall(r'\d{3}',section)
 for sec in sections:records.append(dict(base,section=sec,sourceId='kmou-2026-2-'+base['courseCode']+'-'+sec,canonicalSubjectCodePublished=True,nativeSectionPublished=True))
(p/'third-year-metadata-candidate.json').write_text(json.dumps({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'courses':records,'holds':hold,'sourceScope':'2026-2 항해융합학부 3학년 실습 과목; 실제 날짜·시각 미공개'},ensure_ascii=False,indent=2)+'\n')
print(len(records),'metadata',len(hold),'holds')
