import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['lis2016-01', 'psd2017-01', 'dkl2008-01']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
