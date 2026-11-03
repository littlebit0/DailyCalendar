import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['bus2005-03', 'bus2007-03', 'eng3078-01']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
