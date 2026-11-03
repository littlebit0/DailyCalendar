import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for n in ['iks3016-01', 'skd2075-01', 'skd2083-01']:
 runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{n}-current-attachment-source.json')
