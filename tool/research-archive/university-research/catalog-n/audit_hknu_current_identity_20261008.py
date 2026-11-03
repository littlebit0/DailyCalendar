"""Educational-only current identity crosswalk, not title-only automatic activation."""
import json,pathlib,re,hashlib,collections
from openpyxl import load_workbook
R=pathlib.Path(__file__).resolve().parent

def norm(x):return re.sub(r'\s+','',str(x or ''))
def scalar(x):return '' if x is None else x
original=[]
for campus in ['anseong','pyeongtaek']:
 w=load_workbook(R/f'hknu-2026-2-{campus}.xlsx',data_only=True,read_only=True);s=w.worksheets[0]
 headers=[norm(x.value) for x in s[3]]
 for row in s.iter_rows(min_row=4,values_only=True):
  if row[0] is None:continue
  fields=dict(zip(headers,row));assert '과목코드' in fields
  original.append({'campus':campus,'fields':fields})
current=[];w=load_workbook(R/'hknu-general2026-2-Aug24.xlsx',data_only=True)
for sheet in w:
 headers=[norm(x.value) for x in sheet[3]]
 for row in sheet.iter_rows(min_row=4):
  if row[0].value is None:continue
  f=dict(zip(headers,[c.value for c in row]));campus={'안캠':'anseong','평캠':'pyeongtaek'}.get(f.get('캠퍼스'))
  red=any(c.fill.patternType=='solid' and c.fill.fgColor.type=='rgb' and c.fill.fgColor.rgb=='FFFF0000' for c in row)
  candidates=[o for o in original if norm(o['fields']['과목명'])==norm(f['과목명']) and norm(o['fields']['분반'])==norm(f['분반']) and (campus is None or o['campus']==campus) and norm(o['fields'].get('개설전공') or o['fields']['개설학부'])==norm(f['개설학과'])]
  matches=[]
  for o in candidates:
   a=o['fields'];changed=[]
   for ck,ok in [('과목명','과목명'),('분반','분반'),('학점','학점'),('교수명','교수명'),('시간표','시간표')]:
    if norm(f.get(ck))!=norm(a.get(ok)):changed.append(ck)
   matches.append({'actualCode':a['과목코드'],'actualCampus':o['campus'],'actualOpeningDepartment':a.get('개설전공') or a['개설학부'],'sameIdentityFields':['actualCampus','actualOpeningDepartment','publishedTitle','publishedSection'],'educationDifferences':changed,'allComparedEducationEqual':not changed})
  subject_candidates={str(o['fields']['과목코드']) for o in original if norm(o['fields']['과목명'])==norm(f['과목명']) and norm(o['fields'].get('개설전공') or o['fields']['개설학부'])==norm(f['개설학과'])}
  current.append({'sourceSheet':sheet.title,'sourceRow':row[0].row,'actualEducationalFields':f,'actualRedBackgroundGeneralStudentRestriction':red,'actualCampusField':campus,'directOriginalCampusDepartmentTitleSectionMatches':matches,'publishedSubjectCodeSameTitleDepartmentAcrossOtherSections':sorted(subject_candidates),'codeNotAutomaticallyInventedOrApplied':True})
assert len(original)==1487 and len(current)==340
counts=collections.Counter(len(r['directOriginalCampusDepartmentTitleSectionMatches']) for r in current)
out={'researchOnly':True,'completionClaim':False,'originalRows':1487,'currentRows':340,'identityJoinCounts':dict(counts),'currentRedRestrictedRows':sum(r['actualRedBackgroundGeneralStudentRestriction'] for r in current),'rows':current,'excludedPrivateFields':True,'source':{'currentPublicUrl':'https://www.hknu.ac.kr/bbs/hkcult/305/97200/artclView.do','currentWorkbookDate':'2026-08-24','initialActualCodeDate':'2026-07-14'},'changesNotAutomaticallyApplied':True}
(R/'hknu-current-education-identity-crosswalk-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print('joins',dict(counts),'redrestricted',out['currentRedRestrictedRows'])
for r in current:
 if len(r['directOriginalCampusDepartmentTitleSectionMatches'])!=1:print(r['actualEducationalFields']['과목명'],r['actualEducationalFields']['분반'],r['publishedSubjectCodeSameTitleDepartmentAcrossOtherSections'])
print('current educational comparison differences',collections.Counter(tuple(m['educationDifferences']) for r in current for m in r['directOriginalCampusDepartmentTitleSectionMatches']))
