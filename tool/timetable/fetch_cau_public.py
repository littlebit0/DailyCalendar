"""Read only the official anonymous undergraduate course menu, serially."""
import json, subprocess, time
from pathlib import Path
from tempfile import TemporaryDirectory
BASE = "https://mportal.cau.ac.kr/std/usk/sUskSif001/"
ROOT = Path("work/university-expansion/cau-2026-2")
ROOT.mkdir(parents=True, exist_ok=True)
with TemporaryDirectory() as temp:
    cookie = str(Path(temp)/"public.cookies")
    subprocess.run(["curl","-fsS","--max-time","30","-c",cookie,BASE+"search.do","-o",str(Path(temp)/"page.html")],check=True)
    def query(endpoint, params, name):
        target = ROOT/(name+".json")
        if target.exists(): return json.loads(target.read_text())
        time.sleep(0.5)
        result = subprocess.run(["curl","-fsS","--max-time","30","-b",cookie,"-H","Content-Type: application/json;charset=UTF-8","-H","Referer: "+BASE+"search.do","--data",json.dumps(params),BASE+endpoint+".ajax"],check=True,capture_output=True)
        data = json.loads(result.stdout)
        target.write_text(json.dumps(data,ensure_ascii=False))
        return data
    count=0
    for campus in ["1","2"]:
        params={"campfg":campus,"course":"3","gb":"","year":"2026","shtm":"2"}
        colleges=query("selectParam",params,"campus-"+campus)["selectColg"]
        # These two additional options are explicitly published in the page.
        colleges += [{"deptcd":"LNK"},{"deptcd":"FSN"}]
        seen=set()
        for college in colleges:
            code=college["deptcd"]
            if code in seen: continue
            seen.add(code)
            params["colgcd"]=code
            depts=query("selectSust",params,"departments-"+campus+"-"+code)["selectSust"]
            for dept in depts:
                dep=dept["deptcd"]
                search=dict(params,sust=dep,search_gb=code if code in ["00000","LNK","FSN"] else "ELSE",kornm="")
                if code in ["LNK","FSN"]: search.update(campfg="",course="")
                courses=query("selectSbjt",search,"courses-"+campus+"-"+code+"-"+dep)["selectSust"]
                count+=1
                print(campus,code,dep,len(courses),"queries",count,flush=True)
    print("COMPLETE",count,flush=True)
