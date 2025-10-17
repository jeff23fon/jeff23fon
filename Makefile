# Default variables
PYTHON ?= python
.PHONY: techstacks languages languages-verbose all

# update all
all: techstacks languages

# Update tech stacks in README.md
techstacks:
	$(PYTHON) ./scripts/update_readme.py

# Update language stats and badges in README.md and stats.md
languages:
	bash ./scripts/analyze_languages.sh

languages-verbose:
	bash ./scripts/analyze_languages.sh --verbose
