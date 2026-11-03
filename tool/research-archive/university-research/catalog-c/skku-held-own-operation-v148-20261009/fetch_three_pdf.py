import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for name in ['bus2020','cnt3032','uss2001']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{name}-current-attachment-source.json')
