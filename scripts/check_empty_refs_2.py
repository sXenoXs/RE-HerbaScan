import re

file_path = r'D:\Lenovo2\Code\This_is_IT\RE-HerbaScan\lib\core\services\plant_data_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Split by "return Plant("
plants = content.split('return Plant(')[1:]
for p in plants:
    cn_match = re.search(r"commonName:\s*'([^']+)'", p)
    if not cn_match: continue
    cn = cn_match.group(1)
    if 'references: [],' in p or 'references: []' in p:
        print(f"Empty: {cn}")
