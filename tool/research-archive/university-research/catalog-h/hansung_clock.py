"""Only complete clock blocks explicitly printed in current guide page10."""
import re

DAY75=[('1','2',540,615),('2M','3M',630,705),('4','5',720,795),('5M','6M',810,885),('7','8',900,975),('8M','9M',990,1065),('10','11',1080,1155),('11M','12M',1165,1240),('13','14',1245,1320)]
NIGHT50={10:(1080,1130),11:(1135,1185),12:(1190,1240),13:(1245,1295),14:(1300,1350)}

def clock(day, first, last):
    if day in [1,3,4]:
        blocks=list(DAY75)
        if day==4:blocks[7]=('11M','12M',1180,1250)
        starts={b[0]:i for i,b in enumerate(blocks)};ends={b[1]:i for i,b in enumerate(blocks)}
        if first not in starts or last not in ends:raise ValueError('Partial75minute clock not explicitly published')
        a,b=starts[first],ends[last]
        if a>b:raise ValueError('Reversed clock blocks')
        return blocks[a][2],blocks[b][3]
    if day in [2,5]:
        # Printed50min cells have numeric starts and M-labeled ends.
        if not re.fullmatch(r'\d+',first) or not re.fullmatch(r'\d+M',last):
            raise ValueError('Unpublished partial50minute endpoint')
        a,b=int(first),int(last[:-1])
        if not 1<=a<=b<=14:raise ValueError('Outofscope50minute clock')
        start=(540+(a-1)*60,540+(a-1)*60+50) if a<=9 else NIGHT50[a]
        end=(540+(b-1)*60,540+(b-1)*60+50) if b<=9 else NIGHT50[b]
        return start[0],end[1]
    raise ValueError('Saturday/Sunday clock not published by weekday guide')


def schedules(raw):
    # Room bindings are parsed per explicit slash-separated segment; no ordering guesses.
    out=[]
    for block in raw.split('/'):
        block=block.strip()
        if re.fullmatch(r'온라인강좌\s+[\d.]+시간',block):continue
        match=re.fullmatch(r'(.+?)\s+((?:[월화수목금토일]\d+M?~\d+M?)(?:\s*,\s*[월화수목금토일]\d+M?~\d+M?)*)',block)
        if match is None:raise ValueError('Unrecognized whole room/time block')
        room=match[1].strip()
        for part in match[2].split(','):
            m=re.fullmatch(r'([월화수목금토일])(\d+M?)~(\d+M?)',part.strip())
            day='월화수목금토일'.index(m[1])+1
            start,end=clock(day,m[2],m[3])
            out.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
    return out
