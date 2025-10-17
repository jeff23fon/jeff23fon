import yaml
import re

TECH_STACKS_YAML = "data/tech_stacks.yaml"
README_MD = "README.md"


# Read tech stacks from YAML
with open(TECH_STACKS_YAML, "r") as f:
    tech_stacks = yaml.safe_load(f)

# Generate HTML block
html_block = '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center">\n'
for item in tech_stacks:
    html_block += f'  <a href="{item["href"]}" target="_blank" rel="noopener noreferrer" title="{item["title"]}">\n'
    html_block += f'    <img src="{item["src"]}" alt="{item["alt"]}" width="38" height="38" style="max-width:100%;height:auto;display:block"/>\n'
    html_block += '  </a>\n'
html_block += '</div>\n'

# Read README.md
with open(README_MD, "r") as f:
    content = f.read()

# Replace Tech Stacks block
pattern = r'(## Tech Stacks\n)(<div[\s\S]*?</div>\n)'
new_content = re.sub(pattern, r'\1' + html_block, content)

with open(README_MD, "w") as f:
    f.write(new_content)

print("✅ README.md updated with tech stacks from tech_stacks.yaml!")
