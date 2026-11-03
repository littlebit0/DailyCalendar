import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['eco3031-01', 'eco3043-01', 'iks3027-01']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
