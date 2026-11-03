import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['chi3035-01','eng2019-01','art2054-01']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
