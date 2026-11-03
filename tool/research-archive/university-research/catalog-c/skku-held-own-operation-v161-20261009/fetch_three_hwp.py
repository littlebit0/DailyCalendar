import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['gedw001-06', 'gelt041-42', 'gelt028-41']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
