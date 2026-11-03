import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['pil2004-01', 'com3038-01', 'psd3066-01']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
