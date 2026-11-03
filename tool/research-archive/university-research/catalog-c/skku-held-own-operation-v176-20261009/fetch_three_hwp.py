import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['skd2085-01', 'skd2086-01', 'gld2011-01']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
