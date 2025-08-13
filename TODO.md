# TODOs

- cleanup code, get claude to find duplicate, unused etc code snippets


pls look for unused functions and imports.

Then double- and tripple check that they are not needed, also not in plugin.xml
or somewhere else.

If really sure remove them.
If in doubt do not remove and tell me the name and location so I will check.


Uncertain Items Requiring Your Verification:

1. HarbourLineMarkerProvider.java (intellij-harbour/src/main/java/org/intellij/sdk/language/)
   - Extends RelatedItemLineMarkerProvider but not registered in plugin.xml
   - Could be intended for future use or can be removed
2. HarbourDummyPsiElement.java (intellij-harbour/src/main/java/org/intellij/sdk/language/)
   - Not referenced anywhere in codebase
   - May be for testing purposes or can be removed

Formatting:

  endif
  return <- should be unintended after typed.

Other Findings:

- Found several private methods that appear unused but require careful verification

n2h:

- function / hotkey to add variable under cursor to LOCAL in function