import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['dat2051-01','gedi005-01','ase3002-41']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
