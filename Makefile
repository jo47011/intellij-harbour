# $Id:

IDEA=/home/gruhn/.local/share/JetBrains/IdeaIC2024.3
KIT=$(IDEA)/Grammar-Kit/lib
IDEA_LIB=/opt/idea-IC-243.25659.39/lib/
PRJ = /home/developer/workspace/intellij-harbour
TOOLS = $(PRJ)/tools

all: flex bnf plugin

flex:
	java \
		-Xmx512m \
		-Dfile.encoding=UTF-8 \
		-Dsun.stdout.encoding=UTF-8 \
		-Dsun.stderr.encoding=UTF-8 \
		-jar $(TOOLS)/jflex-1.9.2.jar \
		-skel $(TOOLS)/idea-flex.skeleton \
		-d $(PRJ)/src/main/gen \
		$(PRJ)/src/main/grammar/Harbour.flex

bnf:
	java \
	  -cp "$(KIT)/instrumented-grammar-kit-2023.3.jar:$(IDEA_LIB)/*" \
	  org.intellij.grammar.Main \
	  "$(PRJ)/src/main/gen" \
	  "$(PRJ)/src/main/grammar/Harbour.bnf"

clean-log:
	rm -rf ~/log/*
	rm -f ../logs/*.log
	rm -f ./build/idea-sandbox/IC-2024.3.4/log/idea.log

clean: clean-log
	# Remove all generated Java code from src/main/gen etc.
	./gradlew clean
	rm -rf $(PRJ)/src/main/gen/*
	@$(RM) *~ *.*~ .#* .??*~
	@$(RM) -rf build/*
	@$(RM) -f ../hbmiki-test/log/*
	@echo cleaned.

build:
	# ./gradlew build
	./gradlew buildPlugin --no-configuration-cache

run: build
	./gradlew runIde

plugin:
	./gradlew buildPlugin

# Clean old plugin files before building new one
clean-plugins:
	rm -f ./build/distributions/harbour-language-plugin-*.zip
	rm -f ./build/distributions/harbour-language-plugin-*.js

# Check if on main branch
check-main:
	@if [ "$$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then \
		echo "Error: This operation can only be performed from main branch."; \
		echo "Current branch: $$(git rev-parse --abbrev-ref HEAD)"; \
		exit 1; \
	fi

# Create GitHub release with the built plugin
release: check-main plugin
	@echo "Creating GitHub release for version $$(grep "^version" build.gradle | cut -d"'" -f2)..."
	./gradlew githubRelease
	@echo "Release created! Check https://github.com/jo47011/intellij-harbour/releases"

# Dry run - preview what would be released
release-dry-run: check-main plugin
	./gradlew githubRelease --dry-run

up:
	git pull

update:	up

ci:	clean
	git add -A
	git commit -am "commit all changes"

diff:
	git diff

# eof
