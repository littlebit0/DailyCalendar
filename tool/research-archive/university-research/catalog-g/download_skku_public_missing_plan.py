from skku_public import Public,P,UA,REFERER
import json,urllib.request
p=Public('KO',prefix='skku-ko-')
for code in ['MED3096','MED3173']:
 r=json.loads((P/('skku-ko-medical-attachments-'+code+'.json')).read_text())['dsFile2'][0]
 url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+r['DOWNLOAD_FILE_ID']+'&sequenceNumber='+r['FILE_SEQ']
 data=p.op.open(urllib.request.Request(url,headers={'User-Agent':UA,'Referer':REFERER}),timeout=30).read()
 (P/('skku-'+code+'-official-not-yet-published.txt')).write_bytes(data)
 print(code,len(data),data.decode('utf8',errors='replace'))
