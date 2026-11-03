# -*- coding: utf-8 -*-

from pathlib import Path
import sys, struct, zlib, re, collections, json, hashlib
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT/'work/university-expansion/hwp-tools/lib/python3.9/site-packages'))
import olefile
source=OUT/'학사운영규정_2026.06.17(개정).hwp'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(source)=='f4ffb5f1d516553fb154e2a521f814939862fbca4abfa24bd76042f1a57aed2f'
o=olefile.OleFileIO(source)
header=o.openstream('FileHeader').read()
assert header.startswith(b'HWP Document File')
flags=struct.unpack_from('<I',header,36)[0]
assert not flags & (2|4), 'Protected/distributed source: stop'
sections=[]; alltext=[]
for names in o.listdir():
    if names[0]!='BodyText':
        continue
    b=o.openstream(names).read()
    if flags&1:
        b=zlib.decompress(b,-15)
    pos=0; tags=collections.Counter(); texts=[]
    while pos+4<=len(b):
        value=struct.unpack_from('<I',b,pos)[0]; pos+=4
        tag=value&1023; size=value>>20
        if size==4095:
            size=struct.unpack_from('<I',b,pos)[0]; pos+=4
        payload=b[pos:pos+size]; pos+=size; tags[tag]+=1
        if tag!=67:
            continue
        units=list(struct.unpack('<'+'H'*(len(payload)//2),payload[:len(payload)//2*2]))
        i=0; chars=[]
        while i<len(units):
            unit=units[i]
            if unit in (1,2,3,9,11,12,14,15,16,17,18,21,22,23):
                if unit==9:
                    chars.append('\t')
                i+=8
                continue
            if unit in (10,13):
                chars.append('\n')
            elif unit>=32:
                chars.append(chr(unit))
            i+=1
        texts.append(''.join(chars))
    text='\n'.join(texts)
    alltext.append('=== '+ '/'.join(names)+' ===\n'+text)
    sections.append({'stream':'/'.join(names),'recordsByTag':dict(tags),'textParagraphRecords':len(texts),'HHMatches':re.findall(r'\b\d{1,2}\s*[:：]\s*\d{2}\b',text),'periodWordOccurrences':text.count('교시')})
text='\n\n'.join(alltext)
(OUT/'academic-rule-20260617-clean-paragraphs.txt').write_text(text)
assert '제16조(수업시간) 수업 시간의 단위는 50분 또는 75분으로 한다.' in text
assert '부칙<규정 제2966호, 2026. 6. 17.>' in text
assert len(sections)==4 and all(not s['HHMatches'] for s in sections)
prior=json.loads((ROOT/'work/university-research/catalog-c/jbnu-current-undergraduate-clock-activation-basis-v5-20261009/current-native-clock-activation-gap-proof.json').read_text())
preserved={}
for path,expected in prior['frozenBeforeAndAfterSHA256'].items():
    actual=sha(ROOT/path)
    assert actual==expected, path
    preserved[path]=actual
proof={'sourceFile':source.name,'sourceBytes':source.stat().st_size,'sourceSHA256':sha(source),'acquisition':'Parent observed public university rule UI, normal download, no credentials; authorized local copy from Downloads. Exact direct download URL not provided; not invented. Entry https://www.jbnu.ac.kr/web/intro/situation/rule.do','currentness':'부칙 규정 제2966호 2026.6.17 공포한 날부터 시행; 별표1/1-1/2 2026.6.17 amendment markers','headerFlags':flags,'sections':sections,'embeddedBinDataStreams':[n for n in o.listdir() if n[0]=='BinData'],'previewImageIsOnlyDocumentPreview':True,'literalArticle16':'제16조(수업시간) 수업 시간의 단위는 50분 또는 75분으로 한다.(12.5.18)','literalArticle15Scope':'학장은 전학기 수업종료 전까지 다음학기 수업 시간표를 작성, 공시하고 교무처장에게 제출하여야 한다. 특별한 사유 없이 변경하지 못하며 부득이 변경할 때 사전에 총장 승인.','appendixSubjects':'1/2 졸업이수학점;1-1 연계·융합전공 설치현황;3 공학교육 최소이수학점;4 편입 인정학점;5 평점환산;6 평균산식;7 구실점환산; 별지 수강·출석 관련 빈서식','clockOutcome':'50/75 units reaffirmed; no absolute numeric/A/B start/end, breaks or 0A/B mapping published in this document. No arithmetic extrapolation.','nativeRowsPreserved':3571,'nativeRoomAndWeekdayRows':3338,'directHHRowsInNative':0,'currentDocumentObjectsPreserved':33,'currentScheduledObjectsPreserved':18,'currentDatedMeetingsPreserved':1098,'newEligibleSchedules':0,'candidateCreated':False,'beforeAndAfterSHA256':preserved,'sdkUsed':False,'productChanged':False,'completionClaim':False,'impossibleClaim':False}
(OUT/'current-rule-clock-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
print('PASS: 4 sections / all paragraph and table-cell text records; 3571+33 baselines unchanged; new eligible 0')
