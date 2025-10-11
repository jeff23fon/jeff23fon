#!/bin/bash
if [ -f .env ]; then
  source .env
fi
USERNAME=${USERNAME:-"jeff23fon"}
TOKEN=${TOKEN:-""}
if [ -n "$IGNORED_REPOS" ]; then
  IGNORED_REPOS=(${IGNORED_REPOS})
fi
declare -a IGNORED_REPOS
TOTAL_BYTES=0
declare -A LANG_BYTES

# Fetch repos
REPOS=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/user/repos?type=all&per_page=100" | jq -r '.[].full_name')

# Filter out ignored repos
FILTERED_REPOS=""
for REPO in $REPOS; do
  SKIP=false
  for IGNORED in "${IGNORED_REPOS[@]}"; do
    if [ "$REPO" = "$IGNORED" ]; then
      SKIP=true
      break
    fi
  done
  if [ "$SKIP" = false ]; then
    FILTERED_REPOS="$FILTERED_REPOS $REPO"
  fi
done
REPOS=$FILTERED_REPOS

echo "Total repos fetched: $(echo "$REPOS" | wc -w)"
echo "Repos:"
echo "$REPOS"
echo ""

for REPO in $REPOS; do
  LANGUAGES=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/languages")
  while IFS=':' read -r LANG BYTES; do
    LANG=$(echo $LANG | tr -d '" ')
    BYTES=$(echo $BYTES | tr -d ', ')
    if [[ $BYTES =~ ^[0-9]+$ ]]; then
      LANG_BYTES[$LANG]=$((LANG_BYTES[$LANG] + BYTES))
      TOTAL_BYTES=$((TOTAL_BYTES + BYTES))
    fi
  done <<< "$(printf '%s' "$LANGUAGES" | jq -r 'to_entries[] | "\(.key):\(.value)"')"
done

# Calculate percentages
SORTED=$(for LANG in "${!LANG_BYTES[@]}"; do
  PERCENT=$((LANG_BYTES[$LANG] * 100 / TOTAL_BYTES))
  echo "$LANG:$PERCENT"
done | sort -t: -k2 -nr)

echo "# Language Statistics" > stats.md
echo "" >> stats.md
echo "| Language | Percentage |" >> stats.md
echo "|----------|------------|" >> stats.md

TMP_BADGES=$(mktemp)
: > "$TMP_BADGES"

# Prepare badges file (only >0%)
echo "$SORTED" | while IFS=: read -r LANG PERCENT; do
  echo "$LANG: $PERCENT%"
  echo "| $LANG | $PERCENT% |" >> stats.md
  if [ "$PERCENT" -gt 0 ]; then
    # URL-encode the language label so characters like '#' don't break the badge URL
    if command -v python3 >/dev/null 2>&1; then
      LANG_ESC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$LANG")
    else
      # fallback: replace only common problematic chars
      LANG_ESC=$(echo "$LANG" | sed -e 's/#/%23/g' -e 's/ /%20/g' -e 's/\//%2F/g')
    fi
    printf '![%s](https://img.shields.io/badge/%s-%s%%25-blue)\n' "$LANG" "$LANG_ESC" "$PERCENT" >> "$TMP_BADGES"
  fi
done

# Auto-update README.md: insert badges file under the header
if grep -q '^## Programming Language Distribution' README.md; then
  awk -v file="$TMP_BADGES" '
    BEGIN {infile=file}
    /^## Programming Language Distribution/ { print; while ((getline line < infile) > 0) print line; skip=1; next }
    skip && NF==0 { skip=0; print; next }
    skip { next }
    { print }
  ' README.md > README.md.tmp && mv README.md.tmp README.md
  echo "README.md updated with new badges under '## Programming Language Distribution'."
else
  echo "Section '## Programming Language Distribution' not found in README.md."
fi

rm -f "$TMP_BADGES"
echo ""
echo "Per repo breakdown:"
for REPO in $REPOS; do
  echo "$REPO:"
  LANGUAGES=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/languages")
  if [ -n "$LANGUAGES" ] && [ "$LANGUAGES" != "{}" ]; then
  printf '%s' "$LANGUAGES" | jq -r 'to_entries[] | "\(.key): \(.value) bytes"'
  else
    echo "No languages or empty repo"
  fi
  echo ""
done