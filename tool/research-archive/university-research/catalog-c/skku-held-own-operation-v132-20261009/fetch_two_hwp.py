import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['cla2003-06','chi2029-01']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
