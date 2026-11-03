"""Audit public 2026-2 undergraduate catalog workbooks; never enable app support."""
import collections,json,re
from pathlib import Path
import openpyxl
import pdfplumber
ROOT=Path(__file__).resolve().parent

def text(v):
    return str(v).strip() if v is not None else ''

def sheet_rows(name, fill_merges=False):
    sheet=openpyxl.load_workbook(ROOT/name,data_only=True).worksheets[0]
    rows=[list(row) for row in sheet.values]
    if fill_merges:
        for area in sheet.merged_cells.ranges:
            v=sheet.cell(area.min_row,area.min_col).value
            for ri in range(area.min_row-1,area.max_row):
                for ci in range(area.min_col-1,area.max_col):rows[ri][ci]=v
    return rows

knu=[]
for filename,group in [('knu-2026-2-file-1.xlsx','major'),('knu-2026-2-file-2.xlsx','liberal-teaching-general')]:
    for ri,r in enumerate(sheet_rows(filename)[3:],4):
        identity=text(r[1])
        if not re.fullmatch(r'[A-Z]{4}\d{4}-\d{3}',identity):
            raise ValueError((filename,ri,identity))
        code,section=identity.split('-')
        knu.append(dict(sourceFile=filename,sourceRow=ri,code=code,section=section,title=text(r[5]),credits=r[2],theory=r[3],practice=r[4],targetYear=r[6],category=text(r[7]),schedule=text(r[8]),room=text(r[9]),campus=text(r[10]),college=text(r[11]),department=text(r[12]),major=text(r[13]),professor=text(r[14]),remarks=text(r[15]),sourceGroup=group))
remote_book=openpyxl.load_workbook(ROOT/'knu-2026-2-file-7.xlsx',data_only=True)
metadata={}
for sheet in remote_book:
    for r in list(sheet.values)[3:]:
        if not r[1]:continue
        metadata.setdefault(text(r[1]),[]).append(dict(sheet=sheet.title,remoteType=text(r[15]),remarks=text(r[16])))
for r in knu:r['remoteMetadata']=metadata.get(r['code']+'-'+r['section'],[])

gnu=[]
for filename,group in [('gnu-liberal-2026-2.xlsx','liberal-teaching-general'),('gnu-major-2026-2.xlsx','major')]:
    raw_rows=sheet_rows(filename)
    for ri,r in enumerate(sheet_rows(filename,True)[3:],4):
        # Merged serials span continuation rows; count the original course row only.
        if not text(raw_rows[ri-1][0]).isdigit():continue
        if group=='major':
            code,section=text(r[6]),text(r[7]);title=text(r[4]);category=text(r[5]);schedule=text(r[13]);campus=text(r[12]);remarks=text(r[15])
            row=dict(department=text(r[1]),targetYear=text(r[2]),method=text(r[3]),credits=r[8],theory=r[9],practice=r[10],professor=text(r[11]),remoteType=text(r[14]))
        else:
            code,section=text(r[10]),text(r[11]);title=text(r[8]);category=text(r[1]);schedule=text(r[18]);campus=text(r[17]);remarks=text(r[19])
            row=dict(area=text(r[2]),method=text(r[3]),college=text(r[4]),department=text(r[5]),major=text(r[6]),dayNight=text(r[7]),credits=r[12],theory=r[13],practice=r[14],remoteType=text(r[15]),professor=text(r[16]))
        if not re.fullmatch(r'\d{8}',code) or not re.fullmatch(r'\d{3}',section):raise ValueError((filename,ri,code,section))
        row.update(sourceFile=filename,sourceRow=ri,code=code,section=section,title=title,category=category,schedule=schedule,campus=campus,remarks=remarks,sourceGroup=group)
        gnu.append(row)
closed=set()
for r in sheet_rows('gnu-closed1-2026-2.xlsx')[2:]:
    if not isinstance(r[0],int):continue
    closed.add((text(r[6]),text(r[8])))
for r in gnu:r['closedFirstAnnouncement']=(r['code'],r['section']) in closed

gnu_closed2=set()
for name in ['gnu-closed2-liberal.pdf','gnu-closed2-major.pdf']:
    with pdfplumber.open(ROOT/name) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                for r in table:
                    if len(r)!=16 or not text(r[0]).isdigit():continue
                    assert re.fullmatch(r'\d{8}',text(r[7])) and re.fullmatch(r'\d{3}',text(r[9]))
                    gnu_closed2.add((text(r[7]),text(r[9])))
for r in gnu:r['closedSecondAnnouncement']=(r['code'],r['section']) in gnu_closed2
knu_closures={}
for phase in [1,2]:
    identities=set()
    for r in sheet_rows('knu-closed%d-2026-2.xlsx'%phase)[2:]:
        if not isinstance(r[0],int):continue
        code,section=text(r[1]).split('-');identities.add((code,section))
    knu_closures[phase]=identities
for r in knu:
    r['closedFirstAnnouncement']=(r['code'],r['section']) in knu_closures[1]
    r['closedSecondAnnouncement']=(r['code'],r['section']) in knu_closures[2]

def audit(rows):
    keys=collections.Counter((r['code'],r['section']) for r in rows)
    return dict(sourceRows=len(rows),uniqueCourseSections=len(keys),duplicateCourseSections=[dict(code=k[0],section=k[1],count=v) for k,v in keys.items() if v>1],campuses=dict(collections.Counter(r['campus'] or 'unspecified' for r in rows)),categories=dict(collections.Counter(r['category'] for r in rows)),emptySchedules=sum(not r['schedule'] for r in rows),fullEnablingSafe=False)
report=dict(knu=audit(knu),gnu=audit(gnu))
report['gnu'].update(firstClosureCount=len(closed),closureRowsMatched=sum(r['closedFirstAnnouncement'] for r in gnu),closureIdentitiesMissingFromJulyCatalog=[list(k) for k in sorted(closed-set((r['code'],r['section']) for r in gnu))],activeAfterFirstClosure=sum(not r['closedFirstAnnouncement'] for r in gnu))
report['gnu'].update(secondClosureCount=len(gnu_closed2),secondClosuresMatched=sum(r['closedSecondAnnouncement'] for r in gnu),closureOverlapCount=len(closed & gnu_closed2),activeAfterBothClosures=sum(not(r['closedFirstAnnouncement'] or r['closedSecondAnnouncement']) for r in gnu),secondClosureIdentitiesMissingFromJulyCatalog=[list(k) for k in sorted(gnu_closed2-set((r['code'],r['section']) for r in gnu))])
report['knu'].update(firstClosureCount=len(knu_closures[1]),secondClosureCount=len(knu_closures[2]),firstClosureMatched=sum(r['closedFirstAnnouncement'] for r in knu),secondClosureMatched=sum(r['closedSecondAnnouncement'] for r in knu),activeAfterBothClosures=sum(not(r['closedFirstAnnouncement'] or r['closedSecondAnnouncement']) for r in knu),closureIdentitiesMissingFromJulyCatalog=[list(k) for k in sorted((knu_closures[1]|knu_closures[2])-set((r['code'],r['section']) for r in knu))])
report['knu']['remoteMetadataRows']=sum(len(r['remoteMetadata']) for r in knu)
report['knu']['blockers']=['July 15 snapshot; later lecture changes not reconciled (both closure announcements collected).', 'Actual per-course term dates and special intensive schedule semantics not yet verified.']
report['gnu']['blockers']=['July 24 snapshot; later lecture changes not reconciled (both closure announcements collected).', 'Campus-specific clock and unscheduled/remote exam schedule semantics not yet verified.', 'Actual teaching term dates not yet verified.']
for name,rows in [('knu',knu),('gnu',gnu)]:
    (ROOT/(name+'-public-course-rows.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(ROOT/'knu-gnu-catalog-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
