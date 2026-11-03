import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for n in ['ech2036-42', 'gbe2038-41', 'esm3061-41']:
 runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{n}-current-attachment-source.json')
