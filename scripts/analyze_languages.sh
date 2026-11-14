#!/bin/bash
#
# Scan repos in ~/github/_lang_scan/ using tokei and update README.md
# with language distribution badges.
#
set -euo pipefail

SCAN_DIR="${HOME}/github/_lang_scan"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATS_MD="${PROJECT_DIR}/data/stats.md"
BADGES_FILE="${PROJECT_DIR}/data/stats.badges"
README="${PROJECT_DIR}/README.md"

# Languages to exclude from stats (non-code / inflated)
EXCLUDE_LANGS="JSON|Markdown|Plain Text|SVG|INI|Visual Studio Solution|MSBuild|TOML|YAML"

# Check dependencies
if ! command -v tokei &>/dev/null; then
  echo "❌ tokei not found. Install: cargo install tokei"
  exit 1
fi

if [ ! -d "$SCAN_DIR" ]; then
  echo "❌ Scan directory not found: $SCAN_DIR"
  echo "   Clone your repos there first."
  exit 1
fi

REPO_COUNT=$(find "$SCAN_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ "$REPO_COUNT" -eq 0 ]; then
  echo "❌ No repos found in $SCAN_DIR"
  exit 1
fi

echo "📊 Scanning $REPO_COUNT repos in $SCAN_DIR..."

# Run tokei and process with python for accurate rounding
tokei --output json "$SCAN_DIR" | python3 -c "
import json, sys, urllib.parse

EXCLUDE = set('${EXCLUDE_LANGS}'.split('|'))

data = json.load(sys.stdin)
langs = {}
for lang, info in data.items():
    if lang == 'Total' or lang in EXCLUDE:
        continue
    if isinstance(info, dict) and 'code' in info and info['code'] > 0:
        langs[lang] = info['code']

total = sum(langs.values())
if total == 0:
    print('No code found.', file=sys.stderr)
    sys.exit(1)

# Calculate raw percentages and round
raw = {lang: code * 100.0 / total for lang, code in langs.items()}
rounded = {lang: round(pct) for lang, pct in raw.items()}

# Adjust rounding so they sum to 100
diff = 100 - sum(rounded.values())
if diff != 0:
    # Sort by fractional remainder (descending) to decide who gets +1 or -1
    remainders = sorted(raw.items(), key=lambda x: x[1] - round(x[1]), reverse=(diff > 0))
    for i in range(abs(diff)):
        lang = remainders[i][0]
        rounded[lang] += 1 if diff > 0 else -1

# Sort by percentage descending
sorted_langs = sorted(rounded.items(), key=lambda x: -x[1])

# Write stats.md
with open('${STATS_MD}', 'w') as f:
    f.write('# Language Statistics\n\n')
    f.write('| Language | Percentage |\n')
    f.write('|----------|------------|\n')
    for lang, pct in sorted_langs:
        f.write(f'| {lang} | {pct}% |\n')

# Write badges file (only >0%)
with open('${BADGES_FILE}', 'w') as f:
    for lang, pct in sorted_langs:
        if pct > 0:
            lang_esc = urllib.parse.quote(lang, safe='')
            f.write(f'![{lang}](https://img.shields.io/badge/{lang_esc}-{pct}%25-blue)\n')

# Print summary
for lang, pct in sorted_langs:
    print(f'  {lang}: {pct}%')
print(f'  ---')
print(f'  Total lines of code: {total:,}')
"

# Update README.md: replace content under '## Language Distribution'
if grep -q '^## Language Distribution' "$README"; then
  python3 -c "
import re

with open('${BADGES_FILE}') as f:
    badges = f.read().strip()

with open('${README}') as f:
    content = f.read()

# Replace everything between '## Language Distribution' and the next '##' or EOF
pattern = r'(## Language Distribution\n).*?(?=\n## |\Z)'
replacement = r'\1\n' + badges + '\n'
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open('${README}', 'w') as f:
    f.write(new_content)
"
  echo ""
  echo "✅ README.md updated with language badges."
else
  echo "⚠️  Section '## Language Distribution' not found in README.md."
fi

echo "✅ Scanned $REPO_COUNT repos."
