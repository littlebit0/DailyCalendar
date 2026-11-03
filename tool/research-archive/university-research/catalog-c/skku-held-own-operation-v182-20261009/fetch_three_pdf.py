import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for n in ['ena3036-41', 'snt4039-41', 'snt4045-41']:
 runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{n}-current-attachment-source.json')
