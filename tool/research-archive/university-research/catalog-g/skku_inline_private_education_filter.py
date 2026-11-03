"""Erase contact/identifier tokens in memory while retaining adjacent education.
Ambiguous credentials or remaining private markers discard the line and report loss.
"""
import re
EMAIL=re.compile(r'[A-Z0-9._%+\-]+\s*@\s*[A-Z0-9.\-]+\.[A-Z]{2,}',re.I)
PHONE=re.compile(r'(?<!\d)\(?0\d{1,2}\)?[\s.)\-–—−]+\d{3,4}[\s.\-–—−]+\d{4}(?!\d)|(?<!\d)(?:\+82[- .]?)?0?\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)|(?<!\d)0\d{8,10}(?!\d)|\+\d{1,3}[- .]\d{1,4}[- .]\d{3,4}[- .]\d{4}(?!\d)')
CONTACT_EXTENSION=re.compile(r'(?:Phone|Tel(?:ephone)?|전화(?:번호)?|연락처)\s*[:：]\s*#\s*\d{3,6}\b|(?:내선|ext(?:ension)?\.?)\s*[:：#]?\s*\d{3,6}\b',re.I)
CONTACT_LOCAL_PHONE=re.compile(r'(?:Phone|Tel(?:ephone)?|전화(?:번호)?|연락처)\s*[:：]?\s*\d{3,4}[- .–—−]\d{4}\b',re.I)
IDENTIFIER=re.compile(r'\b(?:PER_ID|GYOGANGSA_ID|담당자번호)\s*[:=]?\s*[A-Za-z0-9_\-]+',re.I)
SECRET_URL=re.compile(r'https?://\S*[?&](?:pwd|token|sessionid|access_token)=\S*',re.I)
DESCRIBED_PASSWORD=re.compile(r'\b(?:password|passwd)\s+to\s+open[^:\n=]{0,90}[:：=]\s*\S+',re.I)
REMAINING_PRIVATE=re.compile(r'@|\b(?:PER_ID|GYOGANGSA_ID)\b|(?:비밀번호|암호|password|passwd)\s*[:=]|\bBearer\s+\S+|[?&](?:pwd|token|sessionid|access_token)=',re.I)

def filter_education(value):
 kept=[];masked=0;lost=0
 for line in str(value or '').splitlines():
  line=re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]','',line)
  for pattern in (EMAIL,PHONE,CONTACT_EXTENSION,CONTACT_LOCAL_PHONE,IDENTIFIER,SECRET_URL,DESCRIBED_PASSWORD):
   line,n=pattern.subn('[비공개 정보 제거]',line);masked+=n
  if REMAINING_PRIVATE.search(line):lost+=1
  else:kept.append(line)
 return '\n'.join(kept),masked,lost

def education(value):
 safe,_,lost=filter_education(value)
 return safe,lost
