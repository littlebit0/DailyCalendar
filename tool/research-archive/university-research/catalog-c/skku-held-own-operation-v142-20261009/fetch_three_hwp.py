import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['klc2009-01','cos3016-01','iai2004-41']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
