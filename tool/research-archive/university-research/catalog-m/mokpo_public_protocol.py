"""Normal published Nexacro XML protocol for official anonymous UNCO04 page.
No login or browser-session extraction. Fresh anonymous cookies remain in memory.
Only published select queries are permitted here.
"""
import urllib.request, http.cookiejar, xml.etree.ElementTree as ET
BASE='https://mnuhs.mokpo.ac.kr:7775/'
ENTRY=BASE+'mnuq/?P=UNCO&ID=UNCO04'
NS='http://www.nexacroplatform.com/platform/dataset'

def bootstrap():
    opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    opener.open(urllib.request.Request(ENTRY,headers={'User-Agent':'Mozilla/5.0','Referer':'https://www.mokpo.ac.kr/www/242/subview.do'}),timeout=25).read()
    return opener

def query(opener, sql_id, parameters):
    root=ET.Element('Root', {'xmlns':NS})
    ps=ET.SubElement(root,'Parameters')
    values={'fsp_action':'nxDefaultAction','fsp_cmd':'execute','fsp_logId':'all',**parameters}
    for key,value in values.items(): ET.SubElement(ps,'Parameter',{'id':key}).text=str(value)
    ds=ET.SubElement(root,'Dataset',{'id':'fsp_ds_cmd'})
    columns=ET.SubElement(ds,'ColumnInfo')
    cmd={'TYPE':'N','SQL_ID':sql_id,'KEY_INCREMENT':'0','KEY_ZERO_LEN':'0','BIZ_NAME':'','EXEC_TYPE':'B'}
    # Exact fsp_init column schema published by sz_fsp_nx.js.
    schema=[('TX_NAME','STRING',100),('TYPE','STRING',10),('SQL_ID','STRING',200),('KEY_SQL_ID','STRING',200),('KEY_INCREMENT','INT',10),('CALLBACK_SQL_ID','STRING',200),('INSERT_SQL_ID','STRING',200),('UPDATE_SQL_ID','STRING',200),('DELETE_SQL_ID','STRING',200),('SAVE_FLAG_COLUMN','STRING',200),('USE_INPUT','STRING',1),('USE_ORDER','STRING',1),('KEY_ZERO_LEN','INT',10),('BIZ_NAME','STRING',100),('PAGE_NO','INT',10),('PAGE_SIZE','INT',10),('READ_ALL','STRING',1),('EXEC_TYPE','STRING',2),('EXEC','STRING',1),('FAIL','STRING',1),('FAIL_MSG','STRING',200),('EXEC_CNT','INT',1),('MSG','STRING',200)]
    for key,kind,size in schema: ET.SubElement(columns,'Column',{'id':key,'type':kind,'size':str(size)})
    rows_node=ET.SubElement(ds,'Rows')
    queries=sql_id if isinstance(sql_id,list) else [sql_id]
    for published_id in queries:
        row=ET.SubElement(rows_node,'Row')
        row_cmd={**cmd,'SQL_ID':published_id}
        for key,value in row_cmd.items(): ET.SubElement(row,'Col',{'id':key}).text=value
    body=ET.tostring(root,encoding='utf-8',xml_declaration=True)
    request=urllib.request.Request(BASE+'NMain',data=body,headers={'User-Agent':'Mozilla/5.0','Content-Type':'text/xml','Referer':ENTRY})
    return opener.open(request,timeout=30).read()

if __name__=='__main__':
    b=query(bootstrap(),'sy/sycm/sycm90:YEAR_HAKGI_S03',{'MENU_CD':'UNCO'})
    root=ET.fromstring(b)
    print('responseBytes',len(b))
    print('parameters',[(e.attrib.get('id'),e.text) for e in root.findall('.//{*}Parameter') if e.attrib.get('id') in ['ErrorCode','ErrorMsg']])
    print('publicYearFields',[(e.attrib.get('id'),e.text) for e in root.findall('.//{*}Col')])
