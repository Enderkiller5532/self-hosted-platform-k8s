import pathlib
import re

root = pathlib.Path(r'C:\Users\Enderkiller5532\k8s').resolve()
pattern = re.compile(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?(?![\w.])')
placeholder = 'IP_PLACEHOLDER'
replaced = []

for path in root.rglob('*'):
    if not path.is_file():
        continue
    if '.git' in path.parts or '.venv' in path.parts:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except Exception:
        continue
    new_text, count = pattern.subn(placeholder, text)
    if count:
        path.write_text(new_text, encoding='utf-8')
        replaced.append((str(path.relative_to(root)), count))

print(f'Replaced files: {len(replaced)}')
for rel, count in replaced:
    print(f'{rel}: {count}')
