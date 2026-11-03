"""Read actual public workbook with existing local xlrd; retain academic cells only."""
from pathlib import Path
import json,re,sys,collections
sys.path.insert(0,'/tmp/daily-catalog-xls-read')
import xlrd
p=Path(__file__).parent
rows=json.loads((p/'jbnu-course-rows.json').read_text())
normalize=lambda s:re.sub(r'\s+','',s)
by_title=collections.defaultdict(list)
for r in rows:by_title[normalize(r['SBJCT_NM'])].append({k:r.get(k) for k in ['SBJCT_NM','STDTR_NO','SBJCT_CD','DVCLS_NO','DOW_HR_CN','DONG_RMNM_CN','LESSN_HR_DIVCDNM']})
titles=sorted(by_title,key=len,reverse=True)
w=xlrd.open_workbook(p/'jbnu-med-2026-2.xls',formatting_info=True)
a=[];sheet_audit=[];unknown=collections.Counter()
for name in ['2026학년도 2학기(1학년)','2학년','3학년','4학년']:
 sh=w.sheet_by_name(name);header=[];count=0;date_errors=[];dated=[]
 for c in range(3,13):
  value=str(sh.cell_value(0,c));m=re.search(r'(\d+)교시\s*(\d{1,2}:\d{2})~(\d{1,2}:\d{2})',value)
  if not m:raise ValueError('Missing published header clock '+name+str(c))
  header.append({'column':c+1,'printedPeriod':int(m[1]),'start':m[2].zfill(5),'end':m[3].zfill(5)})
 for r in range(1,sh.nrows):
  cell=sh.cell(r,1)
  if cell.ctype not in [xlrd.XL_CELL_NUMBER,xlrd.XL_CELL_DATE]:continue
  try:date=xlrd.xldate_as_datetime(cell.value,w.datemode).date()
  except ValueError:continue
  if date.year not in [2026,2027]:continue
  weekday=str(sh.cell_value(r,2)).strip()
  if weekday and weekday not in '월화수목금토일':continue
  if weekday and weekday!='월화수목금토일'[date.weekday()]:date_errors.append({'row':r+1,'date':str(date),'printedWeekday':weekday});continue
  dated.append(str(date))
  for h in header:
   c=h['column']-1;value=str(sh.cell_value(r,c)).strip();inherited=False
   if not value:
    for r1,r2,c1,c2 in sh.merged_cells:
     if r1<=r<r2 and c1<=c<c2:
      value=str(sh.cell_value(r1,c1)).strip();inherited=bool(value);break
   if not value:continue
   norm=normalize(value);match=next((t for t in titles if norm==t or norm.startswith(t+'-') or norm.startswith(t+'(')),None)
   if not match:unknown[name]+=1;continue
   a.append({'sheet':name,'row':r+1,'column':c+1,'date':str(date),'weekday':date.weekday()+1,'start':h['start'],'end':h['end'],'printedPeriod':h['printedPeriod'],'title':by_title[match][0]['SBJCT_NM'],'currentCatalogCandidates':by_title[match],'mergedCellInherited':inherited,'examMarker':bool(re.search('시험|평가|퀴즈',value))});count+=1
 sheet_audit.append({'sheet':name,'rows':sh.nrows,'dateMin':min(dated) if dated else None,'dateMax':max(dated) if dated else None,'recognizedMeetingCells':count,'unmatchedOccupiedCells':unknown[name],'dateWeekdayErrors':date_errors,'publishedClockHeader':header})
result={'noticeUrl':'https://med.jbnu.ac.kr/bbs/med/1901/398340/artclView.do','documentUrl':'https://med.jbnu.ac.kr/bbs/med/1901/357005/download.do','existingReader':'/tmp/daily-catalog-xls-read/xlrd','newDependencyInstalled':False,'sheetAudits':sheet_audit,'meetings':a,'fullInstitutionExceptionAudit':False,'joinCaution':'Only exact normalized published course title prefix matches; multiple current catalog candidates are not assigned a section. Medical printed numeric period labels are not university A/B labels. Use actual date and explicit clock, do not infer 0-B from numeric1 alone.','privacy':'Teacher suffixes and unrelated metadata omitted; no session/login fields','completeAppSupportClaim':False}
(p/'jbnu-med-2026-2-dated-meetings-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({'totalMeetingCells':len(a),'sheets':sheet_audit},ensure_ascii=False))
