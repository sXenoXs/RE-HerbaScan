import re

# Full citations
citations = {
    'Quisumbing (1978)': "Quisumbing, E. A. (1978). Medicinal plants of the Philippines. Katha Publishing Co., Inc. https://catalog.hathitrust.org/Record/001490216",
    'Galvez Tan & Sia (2014)': "Galvez Tan, J. Z., & Sia, I. C. (2014). The best 100 Philippine medicinal plants. Health Futures Foundation, Inc. https://books.google.com.ph/books/about/The_Best_100_Philippine_Medicinal_Plants.html?id=zXkCjwEACAAJ",
    'TKDL-Health (2015)': "Philippine Council for Health Research and Development, & Philippine Institute of Traditional and Alternative Health Care. (2015). Philippine traditional knowledge digital library on health. http://www.tkdlph.com",
    'WHO (1999)': "World Health Organization. (1999). WHO monographs on selected medicinal plants (Vol. 1). World Health Organization. https://apps.who.int/iris/handle/10665/42052",
    'DOH (1997)': "Department of Health. (1997). Traditional and Alternative Medicine Act (TAMA) of 1997 (Republic Act No. 8423). Republic of the Philippines. https://pitahc.gov.ph/republic-act-no-8423/"
}

# Map of plant common name (or id) to list of citation keys
plant_refs = {
    'Lagundi': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Sambong': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Akapulko': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Ampalaya': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Bawang': ['DOH (1997)', 'WHO (1999)', 'Quisumbing (1978)'],
    'Bayabas': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Niyog-niyogan': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Tsaang Gubat': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Ulasimang Bato': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Yerba Buena': ['DOH (1997)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Tawa-Tawa': ['Galvez Tan & Sia (2014)', 'TKDL-Health (2015)', 'Quisumbing (1978)'],
    'Malunggay': ['Galvez Tan & Sia (2014)', 'Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Oregano': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Luya': ['WHO (1999)', 'Quisumbing (1978)', 'Galvez Tan & Sia (2014)'],
    'Aloe Vera': ['WHO (1999)', 'Quisumbing (1978)'],
    'Banaba': ['Galvez Tan & Sia (2014)', 'Quisumbing (1978)'],
    'Calamansi': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Gumamela': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Guyabano': ['Galvez Tan & Sia (2014)', 'Quisumbing (1978)'],
    'Kakawate': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Kamias': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Kamote': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Kamoteng Kahoy': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Mango': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Mayana': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Pomelo': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Saluyot': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Sampa-sampalukan': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Sampalok': ['Quisumbing (1978)', 'TKDL-Health (2015)'],
    'Siling Labuyo': ['Quisumbing (1978)', 'TKDL-Health (2015)']
}

# The actual names in commonName are usually exactly as written above
file_path = r'D:\Lenovo2\Code\This_is_IT\RE-HerbaScan\lib\core\services\plant_data_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

def process_plant(match):
    # match.group(0) is the entire Plant(...) constructor body till imagePath
    text = match.group(0)
    
    # Extract commonName
    cn_match = re.search(r"commonName:\s*'([^']+)'", text)
    if not cn_match:
        # Some fallback logic
        return text
    common_name = cn_match.group(1)
    
    # Check if there's already references
    if 'references:' in text:
        return text

    refs = plant_refs.get(common_name)
    if not refs:
        refs_str = "[]"
    else:
        # Build the dart list of strings
        refs_lines = []
        for ref_key in refs:
            full_ref = citations[ref_key]
            # escape single quotes
            full_ref = full_ref.replace("'", "\\'")
            refs_lines.append(f"        '{full_ref}',")
        refs_str = "[\n" + "\n".join(refs_lines) + "\n      ]"

    # Insert references before imagePath:
    replacement = f"references: {refs_str},\n      imagePath:"
    
    new_text = re.sub(r'imagePath:', replacement, text)
    return new_text

# Regex to match the Plant construction block.
# We match "return Plant(" up to "imagePath:"
# Note that we use a positive lookahead or just match up to imagePath:
new_content = re.sub(r'return Plant\(.*?imagePath:', process_plant, content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Updated plant_data_service.dart")
