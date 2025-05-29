# $Id:

IDEA=/home/gruhn/.local/share/JetBrains/IdeaIC2024.3
KIT=$(IDEA)/Grammar-Kit/lib
IDEA_LIB=/opt/idea-IC-243.25659.39/lib/
PRJ = /home/gruhn/myprog-linux/harbour-language-plugin
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
	@echo cleaned.

build:
	# ./gradlew build
	./gradlew buildPlugin --no-configuration-cache

run: build
	./gradlew runIde

plugin:
	./gradlew buildPlugin


up:
	git pull

update:	up

ci:	clean
	git add -A
	git commit -am "commit all changes"

diff:
	git diff

# eof
