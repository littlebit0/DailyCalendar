import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['his3001-01', 'eng3060-01', 'des2037-01']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
