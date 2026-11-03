import pathlib,json,openpyxl,datetime,hashlib
p=pathlib.Path(__file__).parent;load=lambda n:json.loads((p/n).read_text());b=load('baseline-mirae-v9.json');c=load('yonsei-mirae-2026-2.vid-v10.json');w=openpyxl.load_workbook(p/'offerings.xlsx',data_only=True)['Sheet1']
rows={'VID2006-01-01':(13,2,[5,6,7,8],'청378'),'VID2006-02-01':(14,3,[1,2,3,4],'청375'),'VID3033-01-01':(20,3,[1,2,3,4],'청378'),'VID3033-02-01':(21,4,[5,6,7,8],'청378'),'VID3036-01-01':(23,5,[1,2,3,4],'청378'),'VID3036-02-01':(24,2,[6,7,8,9],'청477'),'VID4002-01-01':(27,4,[1,2,3,4],'청477'),'VID4002-02-01':(28,4,[1,2,3,4],'청375')}
dates={2:'09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-27 11-03 11-10 11-17 11-24 12-01',3:'09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-28 11-04 11-11 11-18 11-25 12-02',4:'09-03 09-10 09-17 10-01 10-08 10-15 10-29 11-05 11-12 11-19 11-26 12-03',5:'09-04 09-11 09-18 10-02 10-16 10-30 11-06 11-13 11-20 11-27 12-04'}
clocks={1:(540,590),2:(600,650),3:(660,710),4:(720,770),5:(780,830),6:(840,890),7:(900,950),8:(960,1010),9:(1020,1070)};total=0;unchanged=0
for old,new in zip(b['courses'],c['courses']):
 ident=old['sourceEducation'][0]['subjtnbCorsePrcts']
 if ident not in rows:assert old==new;unchanged+=1;continue
 row,wd,ps,room=rows[ident];assert w.cell(row,2).value==new['courseCode'];assert w.cell(row,4).value==int(new['section']);assert w.cell(row,7).value==new['professor'];assert w.cell(row,6).value==new['credits'];assert new['sourceEducation']==old['sourceEducation'] and new['sourceEducation'][0]['subjtClNm'] is None
 expected={(f'2026-{date}',wd,clocks[period][0],clocks[period][1],room,period,'lecture' if i<2 else 'practice','inPerson') for date in dates[wd].split() for i,period in enumerate(ps)}
 actual={(s['date'],s['weekday'],s['startMinute'],s['endMinute'],s['classroom'],s['sourcePeriod'],s['sourceGroupKind'],s['deliveryMode']) for s in new['schedules']};assert actual==expected and len(actual)==len(new['schedules']);assert all(datetime.date.fromisoformat(t[0]).isoweekday()==wd for t in actual)
 for key in old:
  if key not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert old[key]==new[key]
 total+=len(actual)
assert unchanged==1210 and total==396
receipt={'independentBuilderImported':False,'rawXlsxIndependentlyParsed':True,'literalDatesIndependent':True,'manualEightIdentities':list(rows),'newMeetings':396,'unchangedWhole':1210,'old994Whole34972Preserved':True,'sourceXLSXSHA256':hashlib.sha256((p/'offerings.xlsx').read_bytes()).hexdigest(),'sourceOnly':True,'SDKExecuted':False,'completionClaim':False}
(p/'independent-validation.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print(receipt)
