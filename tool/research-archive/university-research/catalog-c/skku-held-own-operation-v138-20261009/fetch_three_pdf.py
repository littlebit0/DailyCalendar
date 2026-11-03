import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['skd2061','skd2066','skd2082']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
