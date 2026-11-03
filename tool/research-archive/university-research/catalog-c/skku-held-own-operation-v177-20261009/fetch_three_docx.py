import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['bus2005-02', 'bus3020-01', 'uss7001-01']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
