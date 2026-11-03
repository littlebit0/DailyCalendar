import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['bus2030-01','lis3032-01']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
