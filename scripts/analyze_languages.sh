#!/bin/bash

# Parse --verbose option
VERBOSE=0
for arg in "$@"; do
  if [ "$arg" = "--verbose" ]; then
    VERBOSE=1
  fi
done
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



if [ "$VERBOSE" -eq 1 ]; then
  echo "Total repos fetched: $(echo "$REPOS" | wc -w)"
  echo "Repos:"
  for REPO in $REPOS; do
    echo "$REPO"
  done
  echo ""
fi

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


# Output files in data/
mkdir -p data
STATS_MD="data/stats.md"
BADGES_FILE="data/stats.badges"
: > "$STATS_MD"
: > "$BADGES_FILE"

echo "# Language Statistics" > "$STATS_MD"
echo "" >> "$STATS_MD"
echo "| Language | Percentage |" >> "$STATS_MD"
echo "|----------|------------|" >> "$STATS_MD"

# Prepare badges file (only >0%)
echo "$SORTED" | while IFS=: read -r LANG PERCENT; do
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$LANG: $PERCENT%"
  fi
  echo "| $LANG | $PERCENT% |" >> "$STATS_MD"
  if [ "$PERCENT" -gt 0 ]; then
    # URL-encode the language label so characters like '#' don't break the badge URL
    if command -v python3 >/dev/null 2>&1; then
      LANG_ESC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$LANG")
    else
      LANG_ESC=$(echo "$LANG" | sed -e 's/#/%23/g' -e 's/ /%20/g' -e 's/\//%2F/g')
    fi
    printf '![%s](https://img.shields.io/badge/%s-%s%%25-blue)\n' "$LANG" "$LANG_ESC" "$PERCENT" >> "$BADGES_FILE"
  fi
done

# Auto-update README.md: replace badges under '## Language Distribution' with a blank line after the header
if grep -q '^## Language Distribution' README.md; then
  awk -v file="$BADGES_FILE" '
    BEGIN {infile=file; insection=0}
    /^## Language Distribution/ {
      print; print ""; # print header and blank line
      while ((getline line < infile) > 0) print line;
      insection=1; next
    }
    insection && /^$/ { insection=0; print; next }
    insection { next }
    { print }
  ' README.md > README.md.tmp && mv README.md.tmp README.md
else
  echo "Section '## Language Distribution' not found in README.md."
fi

if [ "$VERBOSE" -eq 1 ]; then
  echo ""
  echo "Per repo breakdown (% per repo):"
  for REPO in $REPOS; do
    echo "$REPO:"
    LANGUAGES=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/languages")
    TOTAL=0
    declare -A REPO_LANG_BYTES
    for ENTRY in $(echo "$LANGUAGES" | jq -r 'to_entries[] | "\(.key):\(.value)"'); do
      LANG=${ENTRY%%:*}
      BYTES=${ENTRY##*:}
      REPO_LANG_BYTES[$LANG]=$BYTES
      TOTAL=$((TOTAL + BYTES))
    done
    if [ "$TOTAL" -gt 0 ]; then
      for LANG in "${!REPO_LANG_BYTES[@]}"; do
        PERCENT=$((REPO_LANG_BYTES[$LANG] * 100 / TOTAL))
        echo "  $LANG: $PERCENT%"
      done
    else
      echo "  No languages or empty repo"
    fi
    echo ""
    unset REPO_LANG_BYTES
  done
  echo ""
fi
echo "✅  README.md updated with new badges under '## Language Distribution'."
REPO_COUNT=$(echo "$REPOS" | wc -w)
echo "✅  README.md updated with $REPO_COUNT repos!"
