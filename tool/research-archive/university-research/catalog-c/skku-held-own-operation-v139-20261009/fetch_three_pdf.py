import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['ena2028','phr2042','phr3120']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
