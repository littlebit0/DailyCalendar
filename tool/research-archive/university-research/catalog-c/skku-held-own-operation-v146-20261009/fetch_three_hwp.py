import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['gedw008-05','gedw013-05','gedw001-05']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
