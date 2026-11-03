import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['skd2044-01', 'skd2060-01', 'skd2062-01']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
