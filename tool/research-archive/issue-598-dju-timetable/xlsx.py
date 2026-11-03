import zipfile,re,sys,json
import xml.etree.ElementTree as ET
NS={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
def col(ref):
    c=re.match(r'[A-Z]+',ref).group(0); n=0
    for ch in c: n=n*26+ord(ch)-64
    return n-1
def read(path):
    z=zipfile.ZipFile(path)
    ss=[]
    if 'xl/sharedStrings.xml' in z.namelist():
        for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',NS):
            ss.append(''.join(t.text or '' for t in si.iter('{%s}t'%NS['m'])))
    wb=ET.fromstring(z.read('xl/workbook.xml'))
    rels=ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    rmap={r.get('Id'):r.get('Target') for r in rels}
    out={}
    for s in wb.find('m:sheets',NS):
        tgt=rmap[s.get('{%s}id'%NS['r'])]; tgt=tgt.lstrip('/'); tgt=tgt if tgt.startswith('xl/') else 'xl/'+tgt
        root=ET.fromstring(z.read(tgt)); rows=[]
        for r in root.iter('{%s}row'%NS['m']):
            row={}
            for c in r.findall('m:c',NS):
                t=c.get('t'); v=c.find('m:v',NS); val=None
                if t=='s' and v is not None: val=ss[int(v.text)]
                elif t=='inlineStr': val=''.join(x.text or '' for x in c.iter('{%s}t'%NS['m']))
                elif v is not None: val=v.text
                if val is not None: row[col(c.get('r'))]=val
            if row:
                m=max(row); rows.append([row.get(i,'') for i in range(m+1)])
        merges=[m.get('ref') for m in root.iter('{%s}mergeCell'%NS['m'])]
        out[s.get('name')]={'rows':rows,'merges':merges}
    return out
if __name__=='__main__':
    d=read(sys.argv[1])
    for k,v in d.items():
        print('## sheet',k,len(v['rows']),'rows; merges',len(v['merges']))
        for r in v['rows'][:int(sys.argv[2]) if len(sys.argv)>2 else 15]: print(r)
