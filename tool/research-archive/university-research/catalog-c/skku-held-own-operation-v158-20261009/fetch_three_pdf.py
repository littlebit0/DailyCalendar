import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for name in ['dasf003-44', 'geds035-42', 'gedw009-41']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{name}-current-attachment-source.json')
