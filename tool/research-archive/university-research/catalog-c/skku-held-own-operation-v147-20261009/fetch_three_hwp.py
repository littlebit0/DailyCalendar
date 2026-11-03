import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['gedw013-08','gedw001-11','gedw001-12']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
