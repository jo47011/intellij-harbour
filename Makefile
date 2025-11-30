# $Id:

# Paths - auto-detect where possible
PRJ := $(shell pwd)
TOOLS = $(PRJ)/tools
GEN = $(PRJ)/src/main/gen
GEN_PKG = $(GEN)/org/intellij/sdk/language

# IntelliJ libs - try multiple locations
IDEA_LIB := $(shell if [ -d "/opt/idea-ce/lib" ]; then echo "/opt/idea-ce/lib"; \
            elif [ -d "/opt/idea-IC-243.25659.39/lib" ]; then echo "/opt/idea-IC-243.25659.39/lib"; \
            else echo "/opt/idea-ce/lib"; fi)

.PHONY: all flex bnf clean clean-log clean-plugins build run plugin help check-main release release-dry-run up update ci diff

all: flex bnf plugin  ## Build everything (flex, bnf, plugin)

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk -F ':.*## ' '{printf "  %-16s %s\n", $$1, $$2}' | sort

flex:  ## Generate lexer from Harbour.flex
	@mkdir -p $(GEN_PKG)
	java \
		-Xmx512m \
		-Dfile.encoding=UTF-8 \
		-Dsun.stdout.encoding=UTF-8 \
		-Dsun.stderr.encoding=UTF-8 \
		-jar $(TOOLS)/jflex-1.9.2.jar \
		-skel $(TOOLS)/idea-flex.skeleton \
		-d $(GEN_PKG) \
		$(PRJ)/src/main/grammar/Harbour.flex

bnf:  ## Generate parser from Harbour.bnf
	java \
	  -cp "$(TOOLS)/instrumented-grammar-kit-2023.3.jar:$(IDEA_LIB)/*" \
	  org.intellij.grammar.Main \
	  "$(GEN)" \
	  "$(PRJ)/src/main/grammar/Harbour.bnf"

clean-log:  ## Clean log files only
	rm -rf ~/log/*
	rm -f ../logs/*.log
	rm -f ./build/idea-sandbox/IC-2024.3.4/log/idea.log

clean: clean-log  ## Clean all generated files and logs
	./gradlew clean
	rm -rf $(PRJ)/src/main/gen/*
	@$(RM) *~ *.*~ .#* .??*~
	@$(RM) -rf build/*
	@echo cleaned.

build:  ## Build plugin with gradle
	./gradlew buildPlugin --no-configuration-cache

run: build  ## Build and run IDE with plugin
	./gradlew runIde

plugin:  ## Build plugin distribution zip
	./gradlew buildPlugin

clean-plugins:  ## Remove old plugin zips
	rm -f ./build/distributions/harbour-language-plugin-*.zip
	rm -f ./build/distributions/harbour-language-plugin-*.js

check-main:  ## Verify on main branch
	@if [ "$$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then \
		echo "Error: This operation can only be performed from main branch."; \
		echo "Current branch: $$(git rev-parse --abbrev-ref HEAD)"; \
		exit 1; \
	fi

release: check-main plugin  ## Create GitHub release
	@echo "Creating GitHub release for version $$(grep "^version" build.gradle | cut -d"'" -f2)..."
	./gradlew githubRelease
	@echo "Release created! Check https://github.com/jo47011/intellij-harbour/releases"

release-dry-run: check-main plugin  ## Preview release without publishing
	./gradlew githubRelease --dry-run

up:  ## Git pull
	git pull

update: up  ## Git pull (alias)

ci: clean  ## Clean and commit all changes
	git add -A
	git commit -am "commit all changes"

diff:  ## Show git diff
	git diff

# eof
