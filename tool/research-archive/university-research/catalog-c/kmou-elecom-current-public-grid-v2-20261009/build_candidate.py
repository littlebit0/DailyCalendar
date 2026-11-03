import copy
import datetime as dt
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path('work/university-research')
P = ROOT / 'catalog-c/kmou-elecom-current-public-grid-v2-20261009'
baseline = json.loads(pathlib.Path('assets/timetable/kmou-unknown-2026-2.json').read_text())
(P/'prior13-current-asset-snapshot.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n')
source = json.loads((P/'current2026-2-revised-grid.hwp.tables.json').read_text())
tables = source[0]['tables']
config = [
    (0,2,2,1,1,{2:'B1-414',3:'B1-414',4:'B1-114'}),
    (0,2,3,1,1,{2:'B1-244',3:'B1-244',4:'B1-244'}),
    (0,6,2,2,2,{6:'B1-145',7:'B1-145',8:'B1-145'}),
    (0,6,3,1,1,{6:'B1-414',7:'B1-414',8:'B1-414',9:'B1-414'}),
    (1,2,1,2,2,{2:'B1-414',3:'B1-414',4:'B1-114'}),
    (1,2,2,2,2,{2:'B1-159',3:'B1-159',4:'B1-159'}),
    (1,2,3,1,1,{2:'B1-145',3:'B1-145',4:'B1-145'}),
    (1,2,4,1,1,{2:'B1-159',3:'B1-159'}),
    (1,6,1,1,1,{6:'B1-159',7:'B1-159',8:'B1-159'}),
    (1,6,2,1,1,{6:'B1-159',7:'B1-159',8:'B1-159'}),
    (1,6,4,1,1,{6:'B1-145',7:'B1-145',8:'B1-145'}),
    (2,2,1,1,1,{2:'B1-159',3:'B1-159',4:'B1-159'}),
    (2,2,2,1,1,{2:'B1-145',3:'B1-145',4:'B1-145'}),
    (2,2,3,2,2,{2:'B1-159',3:'B1-159',4:'B1-159'}),
    (2,6,1,1,1,{6:'B1-414',7:'B1-414',8:'B1-414',9:'B1-414'}),
    (2,6,2,1,1,{6:'B1-414',7:'B1-414',8:'B1-414',9:'B1-414'}),
    (2,6,3,1,1,{6:'B1-159',7:'B1-159',8:'B1-159'}),
]
clock = {n:(480+n*60,530+n*60) for n in range(1,11)}
literal_dates = {1:['2026-09-21','2026-09-28','2026-10-12','2026-10-19'],2:['2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13'],3:['2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14'],4:['2026-09-17','2026-10-01','2026-10-08','2026-10-15']}
# September24 is holiday; October9 is a Friday. Thursday has four dates.
calendar = json.loads((ROOT/'catalog-c/kmou-current-20261008/calendar-operating-education.json').read_text())
closure = json.loads((ROOT/'catalog-c/kmou-current-20261008/closure-education.json').read_text())
excluded = {v['original'] for v in calendar['makeupMapping']}
norm = lambda s:re.sub(r'\s+','',s)
assert len(baseline['courses'])==13 and sum(len(c['schedules']) for c in baseline['courses'])==179
new=[];proof=[]
for ti,row,col,titlecount,profindex,rooms in config:
    cell=next(c for c in tables[ti]['cells'] if c['row']==row and c['column']==col)
    assert cell['rowSpan']==len(rooms) and cell['columnSpan']==1
    paragraphs=cell['paragraphs'];title=''.join(paragraphs[:titlecount]);prof=paragraphs[profindex]
    rawperiods=[];plans=[]
    for period,room in rooms.items():
        header=next(c for c in tables[ti]['cells'] if c['row']==period and c['column']==0)
        text=' / '.join(header['paragraphs']);nums=[int(n) for n in re.findall(r'\d+',text)]
        offset=720 if period>=5 else 0
        start=nums[1]*60+nums[2]+offset;end=nums[3]*60+nums[4]+offset
        assert (start,end)==clock[period]
        assert room in '\n'.join(paragraphs)
        rawperiods.append({'period':period,'clockText':text,'startMinute':start,'endMinute':end,'classroom':room})
    d=dt.date(2026,9,15)
    actual_dates=[]
    while d<=dt.date(2026,10,19):
        if d.isoweekday()==col and d.isoformat() not in excluded:
            actual_dates.append(d.isoformat())
            for r in rawperiods:
                plans.append({'date':d.isoformat(),'weekday':col,'startMinute':r['startMinute'],'endMinute':r['endMinute'],'classroom':r['classroom'],'sourceTable':ti,'sourceRow':r['period'],'sourceColumn':col})
        d+=dt.timedelta(days=1)
    assert actual_dates==literal_dates[col]
    matching=[v for v in closure['courses'] if norm(v['courseName'])==norm(title)]
    assert not matching
    c={'sourceId':f'kmou-document311d69a5-elecom-grade{ti+1}-r{row}c{col}','referenceKind':'document cell locator; not native course code','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':title,'professor':prof,'credits':None,'classification':'','classificationGroup':'','departments':[f'\uc804\uc790\uc815\ubcf4\ud1b5\uc2e0\uacf5\ud559\uc804\uacf5 {ti+1}\ud559\ub144'],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'sourceSchedule':f'{col} weekday / native periods '+','.join(str(v) for v in rooms),'sourceClassroom':' / '.join(dict.fromkeys(rooms.values())),'period':{'startDate':'2026-09-15','endDate':'2026-10-19'},'scheduleStatus':'scheduled','schedules':plans,'sourceEducation':{'attachmentKey':'311d69a5ec10c682fcc491e1ccd862cd','table':ti,'row':row,'column':col,'rowSpan':cell['rowSpan'],'nativeParagraphs':paragraphs,'nativeClockPeriods':rawperiods,'nativeYearHeading':source[0]['paragraphs'][ti*2]['text']},'closureTitleMatches':[],'remarks':'\ud55c\uad6d\ud574\uc591\ub300 \uc804\uc790\uc815\ubcf4\ud1b5\uc2e0\uacf5\ud559\uc804\uacf5 2026-2 \uacf5\uc2dd \uacf5\uac1c \uc218\uc815 \ubb38\uc11c \uae30\uc900 \ubd80\ubd84 \uc608\uc57d. \ucd5c\uc885 \uc2dc\uac04\u00b7\uc7a5\uc18c\ub294 \uc885\ud569\uc815\ubcf4\uc2dc\uc2a4\ud15c \ud655\uc778 \ud544\uc694. \uacf5\uc2dd \uacfc\ubaa9\ucf54\ub4dc\u00b7\uac1c\ubcc4 \ubd84\ubc18\u00b7\ud559\uc810\u00b7\uad6c\ubd84 \ubbf8\uacf5\uac1c, \ubb38\uc11c \uc2dd\ubcc4\uc790\ub294 \uacf5\uc2dd \uacfc\ubaa9\ubc88\ud638\uac00 \uc544\ub2d8. \ucea0\ud37c\uc2a4 \uba85\uce6d \ubbf8\uacf5\uac1c. 9/15~10/19\ub9cc \uc608\uc57d; \ud734\uc77c \uc81c\uc678, \uc911\uac04\uc2dc\ud5d8/\ubcf4\uac15/\ud6c4\ubc18 \uc6b4\uc601\uc740 \uc608\uc57d\ud558\uc9c0 \uc54a\uc74c.'}
    new.append(c);proof.append({'sourceId':c['sourceId'],'courseName':title,'professor':prof,'table':ti,'row':row,'column':col,'literalDates':actual_dates,'literalClockRooms':rawperiods,'actualMeetingCount':len(plans),'closedTitleMatches':matching})
candidate=copy.deepcopy(baseline);candidate['researchOnly']=True;candidate['productionIntegrationEnabled']=False;candidate['completionClaim']=False;candidate['courses'].extend(new)
assert candidate['courses'][:13]==baseline['courses']
(P/'kmou-unknown-2026-2.elecom-partial-v2.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(P/'independent-educational-receipt.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'sourceHWP_SHA256':hashlib.sha256((P/'current2026-2-revised-grid.hwp').read_bytes()).hexdigest(),'prior13Preserved':True,'priorMeetings':179,'newDocumentItems':len(new),'newMeetings':sum(len(c['schedules']) for c in new),'totalItems':len(candidate['courses']),'totalMeetings':sum(len(c['schedules']) for c in candidate['courses']),'literalProofs':proof,'excludedDates':sorted(excluded),'ordinaryNonMaritimeDepartmentScope':True,'officialCodeSectionPublished':False,'pythonChecksPassed':True},ensure_ascii=False,indent=2)+'\n')
selected={(a,b,c) for a,b,c,*_ in config};held=[]
for ti,t in enumerate(tables):
 for c in t['cells']:
  if c['row'] and c['column'] and any(c['paragraphs']) and (ti,c['row'],c['column']) not in selected:
   held.append({'table':ti,'cell':c,'reason':'multiple section alternatives or LMS period-specific attendance/mode unknown or individual capstone allocation/period11-12 clock absent'})
(P/'held-original-cells.json').write_text(json.dumps(held,ensure_ascii=False,indent=2)+'\n')
print('total',len(candidate['courses']),sum(len(c['schedules']) for c in candidate['courses']),'new',len(new),sum(len(c['schedules']) for c in new),'heldCells',len(held))
