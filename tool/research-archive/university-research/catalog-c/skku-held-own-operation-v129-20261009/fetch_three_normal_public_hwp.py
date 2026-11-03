import runpy,pathlib
p=pathlib.Path(__file__).parent
for code in ['ger2035','ger2041','ger3036']:runpy.run_path(str(p/f'fetch_{code}-01_full_education.py'))
