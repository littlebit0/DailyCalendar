import runpy,pathlib,shutil
p=pathlib.Path(__file__).parent
for name in ['gedw023-09', 'med2033-41', 'med2037-41']:
 runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
 shutil.copyfile(p/'current-multiple-public-attachment-source.json',p/f'{name}-current-attachment-source.json')
