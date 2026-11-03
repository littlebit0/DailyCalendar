"""Read actual unencrypted public office attachments in memory, using installed tools.
Protected/distributed HWP is a blocker, never decrypted or bypassed.
"""
import io,sys,struct,zlib,zipfile,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OLE_PATH=ROOT/'work/university-expansion/hwp-tools/lib/python3.9/site-packages'
class ProtectedPublishedOfficeSource(ValueError):
    pass

def hwp_text(body):
    sys.path.insert(0,str(OLE_PATH))
    import olefile
    with olefile.OleFileIO(io.BytesIO(body)) as compound:
        header=compound.openstream('FileHeader').read()
        if not header.startswith(b'HWP Document File'):
            raise ValueError('Not standard published HWP')
        flags=struct.unpack_from('<I',header,36)[0]
        if flags&(2|4):
            raise ProtectedPublishedOfficeSource('Protected/distributed source remains unread; no bypass')
        texts=[]
        for path in compound.listdir():
            if len(path)!=2 or path[0]!='BodyText' or not path[1].startswith('Section'):
                continue
            data=compound.openstream(path).read()
            if flags&1:data=zlib.decompress(data,-15)
            if len(data)>20_000_000:raise ValueError('Public section beyond expected bound')
            position=0
            while position+4<=len(data):
                record=struct.unpack_from('<I',data,position)[0];position+=4
                tag=record&1023;size=record>>20
                if size==4095:
                    if position+4>len(data):raise ValueError('Truncated HWP record')
                    size=struct.unpack_from('<I',data,position)[0];position+=4
                if position+size>len(data):raise ValueError('Truncated HWP paragraph')
                payload=data[position:position+size];position+=size
                if tag==67:
                    text=payload.decode('utf-16le',errors='replace')
                    texts.append(''.join(c if ord(c)>=32 or c in '\n\t' else ' ' for c in text))
        if not texts:raise ValueError('No published readable paragraphs')
        return '\n'.join(texts)
def hwpx_text(body):
    with zipfile.ZipFile(io.BytesIO(body)) as archive:
        texts=[]
        for name in archive.namelist():
            if not name.startswith('Contents/section') or not name.endswith('.xml'):continue
            info=archive.getinfo(name)
            if info.file_size>20_000_000:raise ValueError('Public section beyond expected bound')
            root=ET.fromstring(archive.read(info))
            texts.extend(node.text or '' for node in root.iter() if node.tag.endswith('}t'))
        if not texts:raise ValueError('No readable published HWPX paragraphs')
        return '\n'.join(texts)
def pptx_text(body):
    from pptx import Presentation
    presentation=Presentation(io.BytesIO(body));texts=[]
    for slide in presentation.slides:
        for shape in slide.shapes:
            if shape.has_text_frame:texts.append(shape.text)
            if shape.has_table:
                texts.extend(cell.text for row in shape.table.rows for cell in row.cells)
    return '\n'.join(texts)

def doc_text(body):
    # Installed macOS document reader, standard input/output only; no .doc file,
    # visible app window, Word macros or attachment body is persisted.
    result=subprocess.run(['/usr/bin/textutil','-format','doc','-convert','txt','-stdin','-stdout'],input=body,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=False)
    if result.returncode!=0:
        raise ValueError('Normal native public Word reader did not extract text')
    return result.stdout.decode('utf8',errors='replace')
