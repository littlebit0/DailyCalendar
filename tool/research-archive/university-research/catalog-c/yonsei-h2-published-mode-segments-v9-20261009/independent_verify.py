import pathlib,json,hashlib,datetime as dt,collections
p=pathlib.Path(__file__).parent;load=lambda f:json.loads(f.read_text())
literal={1:['2026-09-07','2026-09-14','2026-09-21','2026-09-28','2026-10-12','2026-10-19','2026-11-02','2026-11-09','2026-11-16','2026-11-23','2026-11-30','2026-12-07'],2:['2026-09-01','2026-09-08','2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13','2026-10-27','2026-11-03','2026-11-10','2026-11-17','2026-11-24','2026-12-01'],3:['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14','2026-10-28','2026-11-04','2026-11-11','2026-11-18','2026-11-25','2026-12-02'],4:['2026-09-03','2026-09-10','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-29','2026-11-05','2026-11-12','2026-11-19','2026-11-26','2026-12-03'],5:['2026-09-04','2026-09-11','2026-09-18','2026-10-02','2026-10-16','2026-10-30','2026-11-06','2026-11-13','2026-11-20','2026-11-27','2026-12-04']}
clocks={0:(480,530),1:(540,590),2:(600,650),3:(660,710),4:(720,770),5:(780,830),6:(840,890),7:(900,950),8:(960,1010),9:(1020,1070),10:(1080,1130)}
base=load(p/'baseline-yonsei-mirae-2026-2.json');new=load(p/'yonsei-mirae-2026-2.mode-segments-v9.json');old={c['sourceId']:c for c in base['courses']};assert len(old)==1218
rows=[];unchanged=0;priorScheduled=0;priorMeetings=0;total=0;special=0;practice=0;fc=0
own75={'yonsei/H2/2026-2/MGT2007-03-00':(2,660,735,'정514',[3,4]),'yonsei/H2/2026-2/MGT3013-01-00':(2,960,1035,'정514',[8,9])}
def splitkind(text):
 if '(' not in text:return [('lecture',text)]
 assert text.count('(')==text.count(')')==1
 a,b=text.split('(',1);inner,z=b.split(')',1)
 return ([('lecture',a)] if a else [])+[('practice',inner)]+([('lecture',z)] if z else [])
for c in new['courses']:
 b=old[c['sourceId']]
 if c==b:unchanged+=1;priorScheduled+=bool(b['schedules']);priorMeetings+=len(b['schedules']);continue
 assert not b['schedules'] and c['partialCoverage'] and c['sourceEducation']==b['sourceEducation']
 for k in b:
  if k not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[k]==b[k]
 assert c['priorHeldResearchRemarks']==b['remarks'] and c['priorHeldDepartmentRemarks']==b['departmentRemarks']
 assert c['publishedModeProof']['H1GuideBorrowed']==False and c['sourceEducation'][0]['sysinstDivCd']=='H2' and c['courseCode']!='YHE1102'
 times=b['sourceSchedule'].split('/');rooms=b['sourceClassroom'].split('/');assert len(times)==len(rooms)==len(c['publishedModeSegments'])
 expected=[]
 for i,(time,room) in enumerate(zip(times,rooms)):
  seg=c['publishedModeSegments'][i];assert seg['index']==i and seg['nativeTime']==time and seg['nativeRoom']==room
  if room in ['동영상(미래,중복수강가능)','동영상(중복수강불가)']:
   assert seg['operation']=='recordedVideoHeld' and not seg['timedReservationsGenerated'] and seg['overlapPermitted']==(room=='동영상(미래,중복수강가능)')
   assert time in c['remarks'] and room in c['remarks'];continue
  assert seg['operation']=='inPerson'
  if c['sourceId'] in own75:
   wd,start,end,where,periods=own75[c['sourceId']];assert i==0 and len([s for s in c['publishedModeSegments'] if s['timedReservationsGenerated']])==1
   assert time==('화3,4' if periods==[3,4] else '화8,9') and room==where
   text='75분 수업(11:00-12:15)' if periods==[3,4] else '75분 수업(16:00-17:15)'
   assert text in b['sourceEducation'][0]['atntnMattrDesc'] and seg['explicit75SourceHH']==text and not seg['general50MinuteClockApplied']
   expected += [(date,wd,start,end,where,'inPerson',i,'lecture',tuple(periods)) for date in literal[wd]];special+=1;continue
  tg=splitkind(time);rg=splitkind(room);assert [x[0] for x in tg]==[x[0] for x in rg]
  for (kind,t),(rkind,where) in zip(tg,rg):
   wd=None
   for token in t.split(','):
    if token[0] in '월화수목금토':wd='월화수목금토'.index(token[0])+1;token=token[1:]
    assert wd in literal and token.isdecimal() and int(token) in clocks
    period=int(token)
    expected += [(date,wd,*clocks[period],where,'inPerson',i,kind,(period,)) for date in literal[wd]]
    if kind=='practice':practice+=len(literal[wd])
 actual=[(s['date'],s['weekday'],s['startMinute'],s['endMinute'],s['classroom'],s['deliveryMode'],s['sourceGroupIndex'],s['sourceGroupKind'],tuple(s.get('sourcePeriods',[s.get('sourcePeriod')]))) for s in c['schedules']]
 assert set(actual)==set(expected) and len(actual)==len(expected)==len(set(actual)) and all(dt.date.fromisoformat(s[0]).isoweekday()==s[1] for s in actual)
 total+=len(actual);rows.append({'sourceId':c['sourceId'],'expectedLiteralFrames':len(expected),'nativeGroupsWholeEqual':True,'exactSourceNativePracticeScope':c['sourceId']=='yonsei/H2/2026-2/IST2007-01-00','explicit75':c['sourceId'] in own75})
 if 'FC (' in (b['sourceEducation'][0]['atntnMattrDesc'] or ''):fc+=1
assert len(rows)==83 and total==1664 and unchanged==1135 and priorScheduled==911 and priorMeetings==33308 and special==2 and practice==13 and fc==54
(p/'independent83-literal-source-preservation-proof.json').write_text(json.dumps({'sourceOnly':True,'SDKExecuted':False,'new83NativeLiteral1664Passed':True,'newGeneral50':81,'newExplicit75':2,'new83VideoAppointments0':True,'nativeGroupsAndFC54RemarksPreserved':True,'FC54':54,'sourceMatched13ISTPracticeFrames':practice,'allOther1135WholeObjectsEqual':True,'prior911Whole33308FramesPreserved':True,'metadata':1218,'scheduled':994,'meetings':34972,'literalDates':literal,'own50MinuteLiteralClocks':clocks,'own75NativeLiteral':own75,'proofByCourse':rows},ensure_ascii=False,indent=2)+'\n')
print('83 independentliteral1664 exact; prior911/33308 wholeequal;1135 otherswholeequal;2explicit75;FC54;practice13')
