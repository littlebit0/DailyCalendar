"""Normal public course-tab traversal using actual published college dictionary."""
import json,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).parent
URL='https://sugang.kookmin.ac.kr/api/subject/public/lectures/conditions/validation/ko'
BASE=dict.fromkeys('stuno locale studentUnivDeptCd scheduleDivCd subjtCd subjtNm professorNm daywCd lessnLestmCd cmpsjDivCd estblCrseDivCd cltrDomnCd dghtDivCd univCd deprtCd bchdmCntcSubjtYn srclnLctreLangDivCd grade cmpsjCdt'.split(),None)
BASE.update(syy='2026',smtCd='20',searchType='02',locale='ko',scheduleSeq=0,offset=0,limit=50)
colleges=json.loads((ROOT/'kookmin-commoncodes.json').read_text())['collegeList']
rows={};audit=[];failures=[]
for index,college in enumerate(colleges):
    code=college['deptCd'];offset=0;received=0;declared=None
    while True:
        body=dict(BASE,univCd=code,deprtCd=code,offset=offset)
        try:
            request=urllib.request.Request(URL,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
            data=json.load(urllib.request.urlopen(request,timeout=30))
            rom=data['lectureRoms'];current=rom['results'];total=rom['totalCount']
            if declared is not None and total!=declared:raise ValueError('Changing total')
            declared=total;received+=len(current)
            for row in current:
                # Preserve public educational metadata, omit employee/contact fields.
                row={k:v for k,v in row.items() if not any(w in k.lower() for w in ['empno','professorno','email','phone','mobile','token','password'])}
                for meeting in row.get('schedule',{}).get('lectureTimes',[]):meeting.pop('instructorId',None)
                if row['id'] in rows and rows[row['id']]!=row:raise ValueError('Conflicting row')
                rows[row['id']]=row
            if received==total:break
            if not current or received>total:raise ValueError('Premature/mismatched page')
            offset+=50
        except (urllib.error.URLError,ValueError,KeyError) as error:
            failures.append({'collegeCode':code,'offset':offset,'errorType':type(error).__name__})
            break
        time.sleep(.25)
    audit.append({'collegeCode':code,'collegeName':college['deptNm'],'declared':declared,'received':received})
    (ROOT/'kookmin-current-college-scope.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'source':URL,'scope':'Actual public college options; default department=college; every pagination followed','collegeQueries':audit,'failures':failures,'records':list(rows.values())},ensure_ascii=False,indent=2)+'\n')
    if (index+1)%10==0:print('College options',index+1,'unique courses',len(rows),'failures',len(failures),flush=True)
    time.sleep(.25)
print('Completed public colleges',len(colleges),'unique courses',len(rows),'failures',len(failures),flush=True)
