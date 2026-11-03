"""Native installed Vision OCR with memory-only image/text transport.
Any real image remains a visual-review candidate, never automatic operating approval.
"""
import json,subprocess
from pathlib import Path
BINARY=Path('/tmp/daily-skku-public-image-reader')
def image_education_text(body):
 if not BINARY.exists():raise ValueError('Installed native OCR helper not compiled; source remains unread')
 if not body or len(body)>20_000_000:raise ValueError('Actual educational image beyond expected safe bound')
 response=subprocess.run([str(BINARY)],input=body,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
 if response.returncode:raise ValueError('Native image reader unavailable; no raw stderr or text output')
 lines=json.loads(response.stdout);selected=[r['text'] for r in lines if r['confidence']>=.8]
 return '\n'.join(selected),{'textRecognitionMode':'installedNativeVision','highConfidenceRecognizedLineCount':len(selected),'lowConfidenceLineCount':len(lines)-len(selected),'requiresVisualOperatingReview':True,'fullImageOrTextSaved':False}
