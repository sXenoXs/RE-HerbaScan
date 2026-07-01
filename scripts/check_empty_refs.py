import re

file_path = r'D:\Lenovo2\Code\This_is_IT\RE-HerbaScan\lib\core\services\plant_data_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find all plants that have empty references
empty_refs = re.findall(r"commonName:\s*'([^']+)',.*?references:\s*\[\],", content, flags=re.DOTALL)
print("Empty refs common names:", empty_refs)
