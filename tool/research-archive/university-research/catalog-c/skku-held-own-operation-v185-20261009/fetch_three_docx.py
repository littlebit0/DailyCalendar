import runpy,pathlib
p=pathlib.Path(__file__).parent
for n in ['ena3033-41', 'iai2006-41', 'skd2089-01']:runpy.run_path(str(p/f'fetch_{n}_full_education.py'))
