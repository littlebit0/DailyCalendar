import runpy,pathlib
p=pathlib.Path(__file__).parent
for name in ['gelt041-03','gelt020-41','gelt028-02']:runpy.run_path(str(p/f'fetch_{name}_full_education.py'))
