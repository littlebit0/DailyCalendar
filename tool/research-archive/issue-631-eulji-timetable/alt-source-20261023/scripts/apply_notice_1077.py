"""을지대 공식 공지 1077(2026-2 교양 시간표)과 1085(폐강 공고)를 자산에 반영한다.
- 기존 강좌 값은 바꾸지 않는다. 폐강 공고에 캠퍼스·과목명·분반이 정확히 같은 교양 강좌만 뺀다.
- 공지에만 있는 '주' 교시 행을 추가한다. 시각은 을지대가 낸 같은 학기 학점교류 시간표의 [수업시간] 표(1교시 09:00~09:50 … 9교시 17:00~17:50)를 쓴다.
- '야' 교시 행은 시각이 공개되지 않아 heldRows로 둔다.
"""
import json,hashlib,re,sys,pathlib
ALT=pathlib.Path(sys.argv[1]); WT=pathlib.Path(sys.argv[2])
URL='https://www.eulji.ac.kr/?menuno=3160&bbsno=1077&boardno=568&ztag=rO0ABXQAMTxjYWxsIHR5cGU9ImJvYXJkIiBubz0iNTY4IiBza2luPSJub3RpY2UiPjwvY2FsbD4%3D&siteno=194&act=view'
CLOSED_URL='https://www.eulji.ac.kr/?menuno=3160&bbsno=1085&boardno=568&ztag=rO0ABXQAMTxjYWxsIHR5cGU9ImJvYXJkIiBubz0iNTY4IiBza2luPSJub3RpY2UiPjwvY2FsbD4%3D&siteno=194&act=view'
WD={'월':1,'화':2,'수':3,'목':4,'금':5,'토':6,'일':7}
T=json.load(open(ALT/'eulji/notice-1077-tables.json'))
closed={(c['campus'],c['name'],c['section']) for c in json.load(open(ALT/'eulji/notice-1085-closed.json'))}
NOT_OPENED={('seongnam','질병과세계사','001')}  # 공지 1077 변경내용: 개설유예(미개설)
TABLES=(1,2,4,5,6,7,8,9,11,12,13,14)
report={'removed':[],'added':{},'heldAdded':[],'skippedClosed':[]}
for camp in ('seongnam','uijeongbu'):
    p=WT/f'assets/timetable/eulji-{camp}-2026-2.json'; d=json.load(open(p))
    keep=[]
    for x in d['courses']:
        k=(camp,x['courseName'],x['section'])
        if x['departments']==['교양'] and k in closed: report['removed'].append(k); continue
        keep.append(x)
    have={(camp,x['courseName'],x['section']) for x in d['courses'] if x['departments']==['교양']}
    heldNames={tuple(re.sub(r'\s+',' ',h['raw']).split(' ')[-7:-5]) for h in d['heldRows']}
    heldKeys=set()
    for h in d['heldRows']:
        m=re.search(r'(\S+)\s+(\d{3})\s+(GRADE|P/NP)',h['raw'])
        if m: heldKeys.add((camp,m[1],m[2]))
    added=0
    for t in T:
        if t['table'] not in TABLES or t['campus']!=camp: continue
        h=t['header']
        for r in t['rows']:
            row=dict(zip(h,r)); name,sec=row['교과목명'],row['분반']; k=(camp,name,sec)
            if k in have: continue
            if k in closed or k in NOT_OPENED: report['skippedClosed'].append(k); continue
            native=' '.join(v for v in r if v)
            m=re.fullmatch(r'주(\d+)~(\d+)',row['교시'])
            if not m:
                if k not in heldKeys:
                    d['heldRows'].append({'campus':camp,'raw':native,'reason':'night clock not published','sourceUrl':URL}); report['heldAdded'].append(k)
                continue
            a,b=int(m[1]),int(m[2]); assert 1<=a<=b<=9, row
            room='' if row['강의실'] in ('-','') else row['강의실']
            cred=int(row['학점']); area=row.get('영역명','')
            remark=row.get('수강 대상') or row.get('비 고') or ''
            sid=hashlib.sha256(f"notice1077|{camp}|{t['table']}|{native}".encode()).hexdigest()[:24]
            keep.append({'sourceId':f'eulji/{camp}/2026/2/{sid}','universityId':'eulji','campus':camp,'campusName':d['campusName'],
              'academicYear':2026,'semester':'2','courseCode':'','courseName':name,'section':sec,'professor':'','credits':cred,
              'schedules':[{'weekday':WD[row['요일']],'startMinute':(8+a)*60,'endMinute':(8+b)*60+50,'classroom':room}],
              'departments':['교양'],'departmentCredits':{'교양':cred},'departmentClassifications':{'교양':f'교양 {area}'.rstrip()},
              'departmentRemarks':{'교양':remark},'scheduleStatus':'scheduled','sourceUrl':URL,'nativeRow':native,
              'sourceSchedule':f"{row['요일']} {row['교시']}",'sourceClassroom':row['강의실'],
              'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}})
            added+=1
    report['added'][camp]=added
    d['courses']=keep; d['sourceRowCount']=len(keep)
    for u in (URL,CLOSED_URL):
        d.setdefault('additionalSourceUrls',[])
        if u not in d['additionalSourceUrls']: d['additionalSourceUrls'].append(u)
    open(p,'w').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
json.dump(report,open(ALT/'apply-report.json','w'),ensure_ascii=False,indent=1)
print(json.dumps({k:(v if k=='added' else len(v)) for k,v in report.items()},ensure_ascii=False)); print(report['removed']); print(report['heldAdded']); print(report['skippedClosed'])
