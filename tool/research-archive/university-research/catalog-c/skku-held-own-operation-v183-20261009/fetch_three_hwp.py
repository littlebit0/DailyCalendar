import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['ech3031-41', 'ech3036-41', 'cal3018-41']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
