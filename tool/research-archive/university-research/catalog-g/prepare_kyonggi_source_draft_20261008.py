"""Source-only current Kyonggi scope and strict actually published clock decisions."""
import json,pathlib,re,collections
R=pathlib.Path(__file__).resolve().parent
rows=json.loads((R/'kyonggi-native-education-recovered-20261008.json').read_text())['rows']
closed={x['code'] for x in json.loads((R/'kyonggi-cancellation-crosscheck.json').read_text()) if x['campus']=='수원'}
clocks={str(n):(480+n*60,530+n*60) for n in range(1,9)}
clocks.update({'1L':(540,615),'2.5L':(630,705),'4L':(720,795),'6L':(840,915),'7.5L':(930,1005)})
result=[]
for r in rows:
 f=r['rawOperatorEducationalFields'];native_times=r['nativeTimeRows'];days=[t['weekday'] for t in native_times];blocks=[re.sub('^주','',t['period']).strip() for t in native_times]
 meetings=[];decision='postedRegularClockCandidate'
 if r['registrationNumber'] in closed:decision='explicitPublishedCancellation'
 elif '집중' in f['remarks']:decision='concentratedDatesUnpublished'
 elif '이러닝' in f['period'] or '이러닝' in f['remarks']:decision='asynchronousSourceNoRealtimeClock'
 elif len(days)!=len(blocks) or not days:decision='timeRowPairingUnresolved'
 else:
  for native_time,day,block in zip(native_times,days,blocks):
   if day not in '월화수목금토일' or len(day)!=1:decision='dayUnresolved';break
   periods=block.split();mapped=[]
   for token in periods:
    if token not in clocks:decision='periodClockNotPublished';break
    mapped.append((token,*clocks[token]))
   if decision!='postedRegularClockCandidate':break
   # Adjacent 60-minute periods are one class block; break is not lecture duration.
   groups=[]
   for token,start,end in mapped:
    if groups and token.isdigit() and groups[-1][-1].isdigit() and int(token)==int(groups[-1][-1])+1:
     groups[-1][1]=end;groups[-1][2]=token
    else:groups.append([start,end,token])
   for start,end,_ in groups:meetings.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':start,'endMinute':end,'classroom':native_time['classroom']})
 if decision!='postedRegularClockCandidate':meetings=[]
 result.append({'actualRegistrationNumber':r['registrationNumber'],'actualCourseCode':f['courseCode'],'nativeSection':'','sourceStableId':f"kyonggi-suwon-2026-2-registration-{r['registrationNumber']}",'actualEducationalFields':f,'sourcePDF':r['sourcePDF'],'sourceSHA256':r['sourceSHA256'],'sourcePage':r['page'],'sourceCellBounds':r['cells'],'nativeTimeRows':native_times,'sourceTimetableDecision':decision,'parsedNativeMeetings':meetings})
counts=dict(collections.Counter(x['sourceTimetableDecision'] for x in result));out={'researchOnly':True,'productionActivationComplete':False,'publishedScope':'Suwon daytime only','rowCount':1640,'allCodesActualNative':all(re.fullmatch('[A-Z]{2,4}\\d{3,4}',x['actualCourseCode']) for x in result),'decisionCounts':counts,'draftRequiresActualRowAndStudentRestrictionAudit':True,'periodAndClosurePolicySourceAudit':'kyonggi-current-period-clock-source-audit-20261008.json','rows':result};(R/'kyonggi-source-clock-candidate-draft-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(counts)
