# -*- coding: utf-8 -*-
"""One exact currently acquired plan, no institution-wide approval."""
from pathlib import Path
import json,re,datetime
R=Path(__file__).resolve().parent
catalog={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education.json').read_text())}
no='1001-7041-00';row=catalog[no];plan=json.loads((R/'cnu-current-education'/f'{no}.json').read_text())
assert row['OPEN_YR']==2026 or str(row['OPEN_YR'])=='2026'
assert row['OPEN_SHTM_CD']=='USR01.20'
assert row['TMTBL_INFO']=='수15:00~18:00(자2201)'
assert len(plan['weeks'])==15
meetings=[]
for week in plan['weeks']:
 text=' '.join(str(week.get(f) or '') for f in ('MAJ_LRN_CTNT','ETC_CTNT','PRJT'))
 found=re.findall(r'(\d{1,2})월\s*(\d{1,2})일\s*\(수\)',text)
 assert len(found)==1,(week.get('WKORD'),'actual date missing or ambiguous')
 month,day=map(int,found[0]);d=datetime.date(2026,month,day)
 assert d.weekday()==2
 assert datetime.date(2026,9,1)<=d<datetime.date(2026,12,21)
 assert '현장' in text and ('강의' in text or '시험' in text)
 meetings.append({'date':d.isoformat(),'weekday':3,'startMinute':900,'endMinute':1080,'location':'자2201','deliveryMode':'inPerson','sourceWeekLabel':week['WKORD'],'proofKind':'sourcePrintedDateWithCurrentCatalogClockAndExplicitPlanRoom','sessionKind':'exam' if '시험' in text else 'class'})
assert len({m['date'] for m in meetings})==15
assert meetings[-1]['date']=='2026-12-16'
assert all(m['date']!='2026-12-09' for m in meetings)
result={'verifiedOn':'2026-10-08','courseId':no,'title':row['SBJT_NM'],'courseCode':row['OPEN_SBJT_NO'],'section':row['OPEN_DCLSS'],'nativeClassification':row['CPTN_DIV_CD_FNM'],'curriculumNativeClassification':row['CURI_CPTN_DIV_NM'],'department':row['OPEN_SUST_MJ_CD_NM'],'creditsOriginal':row['PNT_TMCNT'],'restrictionOriginal':row['TLSN_REST_INFO_CD_NM'],'remarksOriginal':row['TLSN_ANNM'],'originalTimetable':row['TMTBL_INFO'],'planRoomFact':'자연과학대학 2호관(W4) 201호','sourceService':'Uls0604Service/selectTab01List','planResponseSHA256':plan['sourceResponseSHA256'],'dateYearBasis':'current2026-2 course identity and all printed numeric dates/Wednesday agree2026; no other-year clock or date reused','periodStart':'2026-09-02','periodEnd':'2026-12-16','meetings':meetings,'institutionWholeCompletionClaim':False,'notes':['Actual15 dates are printed in this specific current plan; not a repeated-rule expansion','Week label15 is Dec16 after printed week14 Dec2; Dec9 was not invented','현장 강의 interpreted as in-person teaching at explicitly supplied classroom; not inferred off-campus fieldtrip','No instructor contact, staff ID, course topics or access URL stored in this educational candidate']}
(R/'cnu-first-dated-proof-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('verified actual dated meetings',len(meetings))
