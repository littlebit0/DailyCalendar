import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for n in ['gedm001-e4', 'gedw001-57', 'gedi010-i1']:
 runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{n}-current-attachment-source.json')
