import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for name in ['dsc3028-01', 'des2020-02', 'skd2073-01']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{name}-current-attachment-source.json')
