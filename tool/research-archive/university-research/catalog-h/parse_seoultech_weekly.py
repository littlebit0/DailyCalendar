"""Crosscheck actual published weekly classes against the full public catalog."""
from pathlib import Path
from datetime import date
import json,re
import openpyxl
ROOT=Path(__file__).resolve().parent
normalize=lambda s:re.sub(r'\s+','',s or '')
rows=json.loads((ROOT/'seoultech-unique2026-2.json').read_text())
sheet=openpyxl.load_workbook(ROOT/'seoultech-future-weekly.xlsx',data_only=True).active
if sheet.max_row!=100 or sheet.max_column!=17:
    raise ValueError('Unexpected official weekly workbook')
result=[]
for r in range(2,101,3):
    title=sheet.cell(r,1).value
    if not title or sheet.cell(r+1,2).value!='수업시간' or sheet.cell(r+2,2).value!='강의실':
        raise ValueError('Incomplete weekly course group')
    name=title.split('\n')[0].strip()
    candidates=[c for c in rows if normalize(c['SUBJ_KNM'])==normalize(name) and c['SP_LESS_CD_NM']=='미래융합대학']
    if len(candidates)!=1:
        raise ValueError('Ambiguous weekly course identity: '+name)
    course=candidates[0];weeks=[]
    for col in range(3,18):
        published=str(sheet.cell(r,col).value or '').strip()
        times=str(sheet.cell(r+1,col).value or '').strip()
        room=str(sheet.cell(r+2,col).value or '').strip()
        period=re.fullmatch(r'(\d{2}):(\d{2})\s*~\s*(\d{2}):(\d{2})',times)
        week={'week':col-2,'publishedDate':published,'publishedTime':times,'classroom':room}
        if times=='-':
            if room!='VOD':
                raise ValueError('Untimed week without explicit video mode')
            week['mode']='video'
        elif period:
            day=re.fullmatch(r'(\d{2})\.(\d{2})\s*\(([월화수목금토일])\)(?:\s*-\s*.+)?',published)
            if not day:
                raise ValueError('Timed session lacks an explicit single date')
            when=date(2026,int(day[1]),int(day[2]))
            if when.isoweekday()!='월화수목금토일'.index(day[3])+1:
                raise ValueError('Official date/weekday conflict')
            sh,sm,eh,em=map(int,period.groups());start=sh*60+sm;end=eh*60+em
            if not 0<=start<end<=1440 or sm>59 or em>59:
                raise ValueError('Invalid source time')
            week.update(mode='inPerson',date=when.isoformat(),startMinute=start,endMinute=end)
        else:
            raise ValueError('Unrecognized official weekly time')
        weeks.append(week)
    result.append({'courseCode':course['SUBJ_CD'],'section':course['LECT_NUMB'],'title':name,'publishedCourseDescription':title,'weeks':weeks})
(ROOT/'seoultech-future-weekly-verified.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Verified unique courses:',len(result),'dated meetings:',sum('date' in w for c in result for w in c['weeks']),'video weeks:',sum(w['mode']=='video' for c in result for w in c['weeks']))
