import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['gedm001-e3', 'gedm001-e6', 'gelt020-42']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
