# jeff23fon profile repo

# Update language distribution badges in README.md
# Scans repos cloned in ~/github/_lang_scan/
scan:
    bash ./scripts/analyze_languages.sh

# Scan + commit + push in one go
scan-push: scan
    git add -A
    git commit -m "update language stats"
    git push origin main

# Update tech stacks in README.md
techstacks:
    python3 ./scripts/update_readme.py

# Update everything
all: scan techstacks
