import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['skd2052-01','skd2063-01']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
